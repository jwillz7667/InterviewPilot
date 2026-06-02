import { createHash, createPublicKey, createVerify } from 'node:crypto';

import { X509Certificate, X509ChainBuilder } from '@peculiar/x509';
import * as cbor from 'cbor-x';

import { withDatabaseRetry } from '../../config/database.js';
import { getEnv } from '../../config/env.js';
import { AppError } from '../../utils/errors.js';
import { getLogger } from '../../utils/logger.js';

const logger = getLogger().child({ module: 'attest' });

// Apple App Attest CA root, base64-DER. Published by Apple at
// https://www.apple.com/certificateauthority/Apple_App_Attestation_Root_CA.pem
// Embedding the cert means we don't depend on a network fetch for verification.
const APPLE_APP_ATTEST_ROOT_CA_PEM = `-----BEGIN CERTIFICATE-----
MIICITCCAaegAwIBAgIQC/O+DvHN0uD7jG5yH2IXmDAKBggqhkjOPQQDAzBSMSYw
JAYDVQQDDB1BcHBsZSBBcHAgQXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwK
QXBwbGUgSW5jLjETMBEGA1UECAwKQ2FsaWZvcm5pYTAeFw0yMDAzMTgxODMyNTNa
Fw00NTAzMTUwMDAwMDBaMFIxJjAkBgNVBAMMHUFwcGxlIEFwcCBBdHRlc3RhdGlv
biBSb290IENBMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9y
bmlhMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAERTHhmLW07ATaFQIEVwTtT4dyctdh
NbJhFs/Ii2FdCgAHGbpphY3+d8qjuDngIN3WVhQUBHAoMeQ/cLiP1sOUtgjqK9au
Yen1mMEvRq9Sk3Jm5X8U62H+xTD3FE9TgS41o0IwQDAPBgNVHRMBAf8EBTADAQH/
MB0GA1UdDgQWBBSskRBTM72+aEH/pwyp5frq5eWKoTAOBgNVHQ8BAf8EBAMCAQYw
CgYIKoZIzj0EAwMDaAAwZQIwQgFGnByvsiVbpTKwSga0kP0e8EeDS4+sQmTvb7vn
53O5+FRXgeLhpJ06ysC5PrOyAjEAp5U4xDgEgllF7En3VcE3iexZZtKeYnpqtijV
oyFraWVIyd/dganmrduC1bmTBGwD
-----END CERTIFICATE-----`;

const APPLE_APP_ATTEST_OID = '1.2.840.113635.100.8.2';

interface AttestationData {
  fmt: string;
  attStmt: { x5c: Buffer[]; receipt: Buffer };
  authData: Buffer;
}

interface AssertionData {
  signature: Buffer;
  authenticatorData: Buffer;
}

interface ParsedAuthData {
  rpIdHash: Buffer;
  flags: number;
  signCount: number;
  aaguid?: Buffer;
  credentialId?: Buffer;
  credentialPublicKey?: Buffer;
}

function parseAuthData(authData: Buffer): ParsedAuthData {
  if (authData.length < 37) {
    throw new AppError(401, 'authenticator data too short', 'ATTEST_INVALID');
  }
  const rpIdHash = authData.subarray(0, 32);
  const flags = authData[32]!;
  const signCount = authData.readUInt32BE(33);

  const result: ParsedAuthData = { rpIdHash, flags, signCount };

  if (authData.length > 37) {
    const aaguid = authData.subarray(37, 53);
    const credIdLen = authData.readUInt16BE(53);
    const credentialId = authData.subarray(55, 55 + credIdLen);
    const credentialPublicKey = authData.subarray(55 + credIdLen);
    result.aaguid = aaguid;
    result.credentialId = credentialId;
    result.credentialPublicKey = credentialPublicKey;
  }

  return result;
}

function appIdHash(): Buffer {
  const env = getEnv();
  const appId = `${env.APP_ATTEST_TEAM_ID}.${env.APP_ATTEST_BUNDLE_ID}`;
  return createHash('sha256').update(appId).digest();
}

async function verifyCertChain(certs: X509Certificate[]): Promise<void> {
  const root = new X509Certificate(APPLE_APP_ATTEST_ROOT_CA_PEM);
  const builder = new X509ChainBuilder({ certificates: [root, ...certs] });
  const chain = await builder.build(certs[0]!);
  if (chain.length < 2) {
    throw new AppError(401, 'cert chain does not anchor to Apple root', 'ATTEST_CHAIN_INVALID');
  }
  // Verify each cert in the chain was signed by the next.
  for (let i = 0; i < chain.length - 1; i++) {
    const child = chain[i]!;
    const parent = chain[i + 1]!;
    // @peculiar/x509 typings widen these returns to `any`; runtime values
    // are CryptoKey + boolean. Narrow at the boundary.
    // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
    const parentPublicKey = await parent.publicKey.export();
    // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
    const ok: boolean = await child.verify({ publicKey: parentPublicKey });
    if (!ok) {
      throw new AppError(401, 'cert chain signature invalid', 'ATTEST_CHAIN_INVALID');
    }
  }
}

function extractNonceExtension(cert: X509Certificate): Buffer {
  const ext = cert.extensions.find((e) => e.type === APPLE_APP_ATTEST_OID);
  if (!ext) {
    throw new AppError(401, 'attestation extension missing', 'ATTEST_INVALID');
  }
  // Extension value is DER-encoded SEQUENCE { [1] OCTET STRING }
  const raw = Buffer.from(ext.value);
  // Cheap parse: the nonce is the last 32 bytes of the extension payload.
  // The structure is: SEQUENCE { CTX[1] { OCTET_STRING { 32 bytes } } }
  return raw.subarray(raw.length - 32);
}

interface VerifyAttestationParams {
  attestationCbor: Buffer;
  challenge: Buffer;
  keyId: string;
}

export async function verifyAttestation(params: VerifyAttestationParams): Promise<{
  publicKey: Buffer<ArrayBufferLike>;
  receipt: Buffer<ArrayBufferLike>;
  environment: 'appattest' | 'appattestdevelop';
}> {
  const env = getEnv();
  const decoded = cbor.decode(params.attestationCbor) as AttestationData;

  if (decoded.fmt !== 'apple-appattest') {
    throw new AppError(401, `unexpected fmt: ${decoded.fmt}`, 'ATTEST_INVALID');
  }

  const x5c = decoded.attStmt.x5c.map((b) => new X509Certificate(new Uint8Array(b)));
  if (x5c.length === 0) {
    throw new AppError(401, 'no certs in x5c', 'ATTEST_INVALID');
  }

  await verifyCertChain(x5c);

  const credCert = x5c[0]!;
  const nonce = extractNonceExtension(credCert);

  // Expected nonce = sha256(authData || sha256(challenge))
  const clientDataHash = createHash('sha256').update(params.challenge).digest();
  const expectedNonce = createHash('sha256')
    .update(decoded.authData)
    .update(clientDataHash)
    .digest();
  if (!nonce.equals(expectedNonce)) {
    throw new AppError(401, 'attestation nonce mismatch', 'ATTEST_NONCE_MISMATCH');
  }

  // @peculiar/x509 v2's PublicKey.export() returns a CryptoKey, not raw bytes.
  // PublicKey extends PemData<SubjectPublicKeyInfo>, whose .rawData getter
  // returns the SPKI DER ArrayBuffer — which is what Apple's keyId SHA-256s.
  const credPubKeyDer: Buffer<ArrayBufferLike> = Buffer.from(credCert.publicKey.rawData);
  const credPubKeyHash = createHash('sha256').update(credPubKeyDer).digest();
  const expectedKeyId = Buffer.from(params.keyId, 'base64');
  if (!credPubKeyHash.equals(expectedKeyId)) {
    throw new AppError(401, 'keyId does not match cert public key', 'ATTEST_KEY_MISMATCH');
  }

  const auth = parseAuthData(decoded.authData);
  if (!auth.rpIdHash.equals(appIdHash())) {
    throw new AppError(401, 'rpIdHash != appId hash', 'ATTEST_APPID_MISMATCH');
  }
  if (auth.signCount !== 0) {
    throw new AppError(401, 'fresh attestation must have signCount 0', 'ATTEST_INVALID');
  }

  return {
    publicKey: credPubKeyDer,
    receipt: decoded.attStmt.receipt,
    environment: env.APP_ATTEST_ENVIRONMENT,
  };
}

export async function registerAttestation(args: {
  userId: string;
  keyId: string;
  attestationBase64: string;
  challengeBase64: string;
}): Promise<void> {
  const result = await verifyAttestation({
    attestationCbor: Buffer.from(args.attestationBase64, 'base64'),
    challenge: Buffer.from(args.challengeBase64, 'base64'),
    keyId: args.keyId,
  });

  await withDatabaseRetry((prisma) =>
    prisma.appAttestKey.upsert({
      where: { keyId: args.keyId },
      create: {
        keyId: args.keyId,
        userId: args.userId,
        publicKey: new Uint8Array(result.publicKey),
        receipt: new Uint8Array(result.receipt),
        signCount: 0n,
        environment: result.environment,
      },
      update: {
        publicKey: new Uint8Array(result.publicKey),
        receipt: new Uint8Array(result.receipt),
        revokedAt: null,
      },
    })
  );

  logger.info({ userId: args.userId, keyId: args.keyId }, 'attest.key.registered');
}

interface VerifyAssertionParams {
  userId: string;
  keyId: string;
  assertionBase64: string;
  clientData: Buffer; // raw bytes the client signed (typically request body + nonce)
}

export async function verifyAssertion(params: VerifyAssertionParams): Promise<void> {
  const key = await withDatabaseRetry((prisma) =>
    prisma.appAttestKey.findUnique({ where: { keyId: params.keyId } })
  );
  if (!key || key.revokedAt) {
    throw new AppError(401, 'attestation key not registered', 'ATTEST_KEY_UNKNOWN');
  }
  if (key.userId !== params.userId) {
    throw new AppError(401, 'attestation key bound to a different user', 'ATTEST_KEY_MISMATCH');
  }

  const decoded = cbor.decode(Buffer.from(params.assertionBase64, 'base64')) as AssertionData;

  // Step 1: sha256 of clientData
  const clientDataHash = createHash('sha256').update(params.clientData).digest();
  // Step 2: nonce = sha256(authData || clientDataHash)
  const nonce = createHash('sha256')
    .update(decoded.authenticatorData)
    .update(clientDataHash)
    .digest();

  const publicKey = createPublicKey({
    key: Buffer.from(key.publicKey),
    format: 'der',
    type: 'spki',
  });

  const verifier = createVerify('SHA256');
  verifier.update(nonce);
  verifier.end();
  const signatureValid = verifier.verify(publicKey, decoded.signature);
  if (!signatureValid) {
    throw new AppError(401, 'assertion signature invalid', 'ATTEST_SIGNATURE_INVALID');
  }

  const auth = parseAuthData(decoded.authenticatorData);
  if (!auth.rpIdHash.equals(appIdHash())) {
    throw new AppError(401, 'assertion rpIdHash != appId hash', 'ATTEST_APPID_MISMATCH');
  }

  // Counter must be strictly monotonic — replay protection. Fast-path reject
  // gives a clear error for the common (sequential) case.
  const observedSignCount = BigInt(auth.signCount);
  if (observedSignCount <= key.signCount) {
    throw new AppError(401, 'assertion counter not advanced', 'ATTEST_COUNTER_REPLAY');
  }

  // Atomic conditional advance closes the TOCTOU window: two concurrent requests
  // carrying the same assertion both pass the read-time check above, but only the
  // first UPDATE whose WHERE still sees the lower counter succeeds. count !== 1
  // means another request already consumed this (or a higher) counter value.
  const advanced = await withDatabaseRetry((prisma) =>
    prisma.appAttestKey.updateMany({
      where: { keyId: params.keyId, signCount: { lt: observedSignCount } },
      data: { signCount: observedSignCount, lastUsedAt: new Date() },
    })
  );
  if (advanced.count !== 1) {
    throw new AppError(401, 'assertion counter not advanced', 'ATTEST_COUNTER_REPLAY');
  }
}
