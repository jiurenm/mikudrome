import { proxyBackendRequest } from "../../../../../src/server/apiProxy";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

interface AlbumCoverRouteContext {
  params: Promise<{
    albumId: string;
  }>;
}

export async function GET(
  _request: Request,
  context: AlbumCoverRouteContext
): Promise<Response> {
  const { albumId } = await context.params;

  return proxyBackendRequest(`/api/albums/${encodeURIComponent(albumId)}/cover`, {
    method: "GET"
  });
}
