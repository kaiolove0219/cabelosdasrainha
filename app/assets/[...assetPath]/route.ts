import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const CONTENT_TYPES: Record<string, string> = {
  ".avif": "image/avif",
  ".gif": "image/gif",
  ".ico": "image/x-icon",
  ".jpeg": "image/jpeg",
  ".jpg": "image/jpeg",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".txt": "text/plain; charset=utf-8",
  ".webp": "image/webp",
};

const ROUTE_DIRECTORY = path.dirname(fileURLToPath(import.meta.url));
const ASSETS_ROOT = path.resolve(ROUTE_DIRECTORY, "../../../assets");

function resolveAssetPath(assetPath: string[]) {
  const filePath = path.resolve(ASSETS_ROOT, ...assetPath);

  if (filePath !== ASSETS_ROOT && !filePath.startsWith(`${ASSETS_ROOT}${path.sep}`)) {
    return null;
  }

  return filePath;
}

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ assetPath: string[] }> },
) {
  const { assetPath } = await params;
  const filePath = resolveAssetPath(assetPath);

  if (!filePath) {
    return new Response("Forbidden", { status: 403 });
  }

  try {
    const file = await readFile(filePath);
    const extension = path.extname(filePath).toLowerCase();

    return new Response(file, {
      headers: {
        "cache-control": "public, max-age=31536000, immutable",
        "content-type": CONTENT_TYPES[extension] ?? "application/octet-stream",
      },
    });
  } catch {
    return new Response("Not Found", { status: 404 });
  }
}
