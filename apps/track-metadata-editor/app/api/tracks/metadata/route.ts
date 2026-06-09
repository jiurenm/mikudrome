import { proxyBackendRequest } from "../../../../src/server/apiProxy";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(): Promise<Response> {
  return proxyBackendRequest("/api/tracks/metadata", {
    method: "GET"
  });
}
