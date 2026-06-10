import { searchVocaDbAlbums, VocaDbProxyError } from "../../../../../src/server/vocadbProxy";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(request: Request): Promise<Response> {
  const url = new URL(request.url);

  try {
    const albums = await searchVocaDbAlbums(url.searchParams.get("query") ?? "");
    return Response.json({ albums });
  } catch (error) {
    if (error instanceof VocaDbProxyError) {
      return Response.json({ error: error.message }, { status: error.status });
    }

    throw error;
  }
}
