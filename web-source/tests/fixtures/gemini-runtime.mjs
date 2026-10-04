import { DatabaseSync } from "node:sqlite";
import { readFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
export const sqlite = new DatabaseSync(":memory:");
const journal = JSON.parse(readFileSync("drizzle/meta/_journal.json", "utf8"));
for (const entry of journal.entries)
  sqlite.exec(readFileSync("drizzle/" + entry.tag + ".sql", "utf8"));
let owner = "account-A";
export function setOwner(value) {
  owner = value;
}
export async function headers() {
  return new Headers(owner ? { "oai-authenticated-user-id": owner } : {});
}
export function after(callback) {
  void Promise.resolve().then(callback);
}
export const env = {
  GEMINI_KEY_ENCRYPTION_SECRET: randomBytes(32).toString("base64"),
  DB: {
    prepare(sql) {
      const statement = sqlite.prepare(sql);
      let args = [];
      return {
        bind(...values) {
          args = values;
          return this;
        },
        async run() {
          const r = statement.run(...args);
          return { meta: { changes: Number(r.changes) } };
        },
        async first() {
          return statement.get(...args) || null;
        },
        async all() {
          return { results: statement.all(...args), success: true, meta: { changes: 0 } };
        },
      };
    },
    async batch(statements) {
      sqlite.exec("BEGIN");
      try {
        const results = [];
        for (const s of statements) results.push(await s.run());
        sqlite.exec("COMMIT");
        return results;
      } catch (e) {
        sqlite.exec("ROLLBACK");
        throw e;
      }
    },
  },
};
