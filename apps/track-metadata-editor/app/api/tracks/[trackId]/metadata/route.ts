import { proxyBackendRequest } from "../../../../../src/server/apiProxy";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

interface TrackMetadataRouteContext {
  params: Promise<{
    trackId: string;
  }>;
}

export async function PATCH(
  request: Request,
  context: TrackMetadataRouteContext
): Promise<Response> {
  const { trackId } = await context.params;

  return proxyBackendRequest(`/api/tracks/${encodeURIComponent(trackId)}/metadata`, {
    method: "PATCH",
    contentType: request.headers.get("content-type") ?? "application/json",
    body: await request.text()
  });
}
