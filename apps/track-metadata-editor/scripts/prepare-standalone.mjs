import { cpSync, existsSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const appRoot = process.cwd();
const standaloneRoot = join(appRoot, ".next", "standalone");

if (!existsSync(standaloneRoot)) {
  process.exit(0);
}

const standaloneNextRoot = join(standaloneRoot, ".next");
const staticSource = join(appRoot, ".next", "static");
const staticTarget = join(standaloneNextRoot, "static");

if (existsSync(staticSource)) {
  mkdirSync(standaloneNextRoot, { recursive: true });
  cpSync(staticSource, staticTarget, { recursive: true, force: true });
}

const publicSource = join(appRoot, "public");
const publicTarget = join(standaloneRoot, "public");

if (existsSync(publicSource)) {
  cpSync(publicSource, publicTarget, { recursive: true, force: true });
}
