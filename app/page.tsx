import { LegacyLanding } from "@/components/legacy-landing";
import { loadLegacyLanding } from "@/lib/load-legacy-landing";

export const dynamic = "force-dynamic";

export default async function Home() {
  const { bodyHtml, styles } = await loadLegacyLanding();

  return (
    <>
      <style dangerouslySetInnerHTML={{ __html: styles }} />
      <LegacyLanding html={bodyHtml} />
    </>
  );
}

