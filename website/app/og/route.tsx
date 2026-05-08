import { ImageResponse } from "next/og";

export const runtime = "edge";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const title = searchParams.get("title") ?? "Interview Ace";
  const subtitle =
    searchParams.get("subtitle") ?? "Real-time AI interview coach";
  const eyebrow = searchParams.get("eyebrow") ?? "Interview Ace";

  return new ImageResponse(
    (
      <div
        style={{
          height: "100%",
          width: "100%",
          display: "flex",
          flexDirection: "column",
          background:
            "linear-gradient(135deg, #0a0e14 0%, #0f1f3d 50%, #0a4ec0 100%)",
          padding: "80px",
          position: "relative",
          fontFamily: "Inter, system-ui, sans-serif",
        }}
      >
        <div
          style={{
            position: "absolute",
            inset: 0,
            backgroundImage:
              "radial-gradient(circle at 20% 20%, rgba(80,140,255,0.25), transparent 50%), radial-gradient(circle at 80% 80%, rgba(70,210,180,0.18), transparent 50%)",
            display: "flex",
          }}
        />
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: "12px",
            zIndex: 1,
          }}
        >
          <div
            style={{
              width: "44px",
              height: "44px",
              borderRadius: "12px",
              background: "linear-gradient(135deg, #4d9eff, #50e3c2)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontSize: "24px",
              fontWeight: 800,
              color: "#0a0e14",
            }}
          >
            A
          </div>
          <div
            style={{
              fontSize: "26px",
              fontWeight: 600,
              color: "rgba(255,255,255,0.85)",
              letterSpacing: "-0.01em",
            }}
          >
            {eyebrow}
          </div>
        </div>
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            justifyContent: "flex-end",
            flex: 1,
            zIndex: 1,
          }}
        >
          <div
            style={{
              fontSize: "84px",
              fontWeight: 800,
              color: "#fff",
              lineHeight: 1.05,
              letterSpacing: "-0.04em",
              maxWidth: "1000px",
            }}
          >
            {title}
          </div>
          <div
            style={{
              fontSize: "32px",
              fontWeight: 400,
              color: "rgba(255,255,255,0.7)",
              marginTop: "24px",
              letterSpacing: "-0.01em",
              maxWidth: "950px",
            }}
          >
            {subtitle}
          </div>
        </div>
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            zIndex: 1,
            marginTop: "32px",
          }}
        >
          <div
            style={{
              fontSize: "22px",
              color: "rgba(255,255,255,0.55)",
            }}
          >
            interviewace.app
          </div>
          <div
            style={{
              display: "flex",
              gap: "24px",
              fontSize: "20px",
              color: "rgba(255,255,255,0.5)",
            }}
          >
            <span>Live transcription</span>
            <span>·</span>
            <span>Tailored answers</span>
            <span>·</span>
            <span>Post-interview analytics</span>
          </div>
        </div>
      </div>
    ),
    {
      width: 1200,
      height: 630,
      headers: {
        "Cache-Control": "public, immutable, max-age=31536000",
      },
    },
  );
}
