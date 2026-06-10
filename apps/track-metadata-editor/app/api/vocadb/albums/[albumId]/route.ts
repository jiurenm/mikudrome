import { getVocaDbAlbum, VocaDbProxyError } from "../../../../../src/server/vocadbProxy";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

interface VocaDbAlbumRouteContext {
  params: Promise<{
    albumId: string;
  }>;
}

export async function GET(
  _request: Request,
  context: VocaDbAlbumRouteContext
): Promise<Response> {
  const { albumId: rawAlbumId } = await context.params;
  const albumId = Number(rawAlbumId);

  if (!Number.isInteger(albumId) || albumId <= 0 || String(albumId) !== rawAlbumId) {
    return Response.json({ error: "Invalid VocaDB album id." }, { status: 400 });
  }

  try {
    const album = await getVocaDbAlbum(albumId);
    return Response.json({ album });
  } catch (error) {
    if (error instanceof VocaDbProxyError) {
      return Response.json({ error: error.message }, { status: error.status });
    }

    throw error;
  }
}
