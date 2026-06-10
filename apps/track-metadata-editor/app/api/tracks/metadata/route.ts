import { proxyBackendRequest } from "../../../../src/server/apiProxy";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(): Promise<Response> {
  return proxyBackendRequest("/api/tracks/metadata", {
    method: "GET"
  });
}

export async function PATCH(request: Request): Promise<Response> {
  return proxyBackendRequest("/api/tracks/metadata", {
    method: "PATCH",
    contentType: request.headers.get("content-type") ?? "application/json",
    body: await request.text()
  });
}
