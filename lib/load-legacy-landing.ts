import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const STYLE_PATTERN = /<style>([\s\S]*?)<\/style>/i;
const BODY_PATTERN = /<body[^>]*>([\s\S]*?)<\/body>/i;
const TRAILING_SCRIPT_PATTERN = /<script[\s\S]*?<\/script>\s*$/i;

type LegacyLandingSource = {
  bodyHtml: string;
  styles: string;
};

const MODULE_DIRECTORY = path.dirname(fileURLToPath(import.meta.url));

export async function loadLegacyLanding(): Promise<LegacyLandingSource> {
  const filePath = path.resolve(MODULE_DIRECTORY, "../index.html");
  const source = await readFile(filePath, "utf8");
  const styleMatch = source.match(STYLE_PATTERN);
  const bodyMatch = source.match(BODY_PATTERN);

  if (!styleMatch || !bodyMatch) {
    throw new Error("Nao foi possivel extrair o CSS e o HTML do index.html legado.");
  }

  return {
    bodyHtml: bodyMatch[1].replace(TRAILING_SCRIPT_PATTERN, "").trim(),
    styles: styleMatch[1].trim(),
  };
}
