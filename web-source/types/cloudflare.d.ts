// Narrow runtime contracts used by this application. Deployment supplies bindings.
interface Fetcher {
  fetch(request: Request): Promise<Response>;
}
interface D1Result<T = unknown> {
  results: T[];
  success: boolean;
  meta: { changes: number; [key: string]: unknown };
}
interface D1PreparedStatement {
  bind(...values: unknown[]): D1PreparedStatement;
  first<T = Record<string, unknown>>(column?: string): Promise<T | null>;
  all<T = Record<string, unknown>>(): Promise<D1Result<T>>;
  run<T = Record<string, unknown>>(): Promise<D1Result<T>>;
  raw<T = unknown[]>(): Promise<T[]>;
}
interface D1Database {
  prepare(query: string): D1PreparedStatement;
  batch<T = unknown>(statements: D1PreparedStatement[]): Promise<D1Result<T>[]>;
  exec(query: string): Promise<{ count: number; duration: number }>;
  dump(): Promise<ArrayBuffer>;
}
declare module "cloudflare:workers" {
  export const env: {
    DB: D1Database;
    AUDIO?: {
      delete(key:string):Promise<void>;
      get(key:string):Promise<{body:ReadableStream;size:number;customMetadata?:Record<string,string>;writeHttpMetadata(headers:Headers):void}|null>;
      put(key:string,value:ArrayBuffer,options:{httpMetadata:{contentType:string;cacheControl:string};customMetadata:Record<string,string>}):Promise<unknown>;
    };
    ASSETS: Fetcher;
    OPENAI_API_KEY?: string;
    OPENAI_TEXT_MODEL?: string;
    GEMINI_API_KEY?: string;
    AZURE_SPEECH_KEY?: string;
    AZURE_SPEECH_REGION?: string;
    GEMINI_KEY_ENCRYPTION_SECRET?: string;
  };
}
