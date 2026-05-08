import { Hero } from "@/components/sections/hero";
import { SocialProof } from "@/components/sections/social-proof";
import { Features } from "@/components/sections/features";
import { HowItWorks } from "@/components/sections/how-it-works";
import { Pricing } from "@/components/sections/pricing";
import { Testimonials } from "@/components/sections/testimonials";
import { FAQ } from "@/components/sections/faq";
import { CTA } from "@/components/sections/cta";
import { JsonLd } from "@/components/json-ld";
import {
  organizationSchema,
  websiteSchema,
  softwareApplicationSchema,
} from "@/lib/structured-data";

export default function HomePage() {
  return (
    <>
      <JsonLd
        data={[organizationSchema(), websiteSchema(), softwareApplicationSchema()]}
      />
      <Hero />
      <SocialProof />
      <Features />
      <HowItWorks />
      <Pricing />
      <Testimonials />
      <FAQ />
      <CTA />
    </>
  );
}
