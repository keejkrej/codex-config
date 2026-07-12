#!/usr/bin/env node
/** Deep-merge orchestration essentials into ~/.codex/config.toml. */

import { mkdir, readFile, writeFile, lstat, unlink } from "node:fs/promises";
import { dirname } from "node:path";
import { parse } from "smol-toml";

function loadToml(path) {
  return readFile(path, "utf8")
    .then((text) => parse(text))
    .catch((err) => {
      if (err.code === "ENOENT") return {};
      throw err;
    });
}

function deepMerge(base, overlay) {
  const merged = { ...base };
  for (const [key, value] of Object.entries(overlay)) {
    if (
      key in merged &&
      isPlainObject(merged[key]) &&
      isPlainObject(value)
    ) {
      merged[key] = deepMerge(merged[key], value);
    } else {
      merged[key] = value;
    }
  }
  return merged;
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function formatKeyPart(part) {
  if (/^[A-Za-z0-9_-]+$/.test(part)) return part;
  return `"${part.replaceAll("\\", "\\\\").replaceAll('"', '\\"')}"`;
}

function formatString(value) {
  if (value.includes("\n")) return `'''${value}'''`;
  return `"${value.replaceAll("\\", "\\\\").replaceAll('"', '\\"')}"`;
}

function formatValue(value) {
  if (typeof value === "boolean") return value ? "true" : "false";
  if (typeof value === "number") return Number.isInteger(value) ? String(value) : String(value);
  if (typeof value === "string") return formatString(value);
  if (Array.isArray(value)) return `[${value.map(formatValue).join(", ")}]`;
  throw new TypeError(`unsupported TOML value type: ${typeof value}`);
}

function writeSection(data, path, out) {
  const scalars = [];
  const tables = [];

  for (const [key, value] of Object.entries(data)) {
    if (isPlainObject(value)) tables.push([key, value]);
    else scalars.push([key, value]);
  }

  if (path.length > 0) {
    out.push(`[${path.map(formatKeyPart).join(".")}]`);
  }

  for (const [key, value] of scalars) {
    out.push(`${formatKeyPart(key)} = ${formatValue(value)}`);
  }

  if (path.length > 0 && (scalars.length > 0 || tables.length > 0)) {
    out.push("");
  }

  for (const [key, value] of tables) {
    writeSection(value, [...path, key], out);
  }
}

function dumpToml(data) {
  const lines = [];
  writeSection(data, [], lines);
  return `${lines.join("\n").trimEnd()}\n`;
}

async function materializeSymlink(path) {
  const stat = await lstat(path);
  if (!stat.isSymbolicLink()) return false;
  const content = await readFile(path);
  await unlink(path);
  await writeFile(path, content);
  return true;
}

async function main() {
  const [essentialsPath, destPath] = process.argv.slice(2);
  if (!essentialsPath || !destPath) {
    console.error("usage: merge_config.mjs <essentials.toml> <dest.toml>");
    process.exit(1);
  }

  try {
    if (await lstat(destPath).then((s) => s.isSymbolicLink()).catch(() => false)) {
      console.log(`materialized symlink at ${destPath}`);
      await materializeSymlink(destPath);
    }
  } catch {
    // dest may not exist yet
  }

  const essentials = await loadToml(essentialsPath);
  if (Object.keys(essentials).length === 0) {
    console.error(`no essentials found in ${essentialsPath}`);
    process.exit(1);
  }

  const existing = await loadToml(destPath);
  const merged = deepMerge(existing, essentials);

  try {
    await lstat(destPath);
    const backup = `${destPath}.bak.${Math.floor(Date.now() / 1000)}`;
    await writeFile(backup, await readFile(destPath));
    console.log(`backed up existing config to ${backup}`);
  } catch (err) {
    if (err.code !== "ENOENT") throw err;
  }

  await mkdir(dirname(destPath), { recursive: true });
  await writeFile(destPath, dumpToml(merged), "utf8");
  console.log(`merged orchestration essentials into ${destPath}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});