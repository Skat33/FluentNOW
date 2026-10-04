const utf8 = new TextEncoder();
const encode = (b: Uint8Array) => btoa(String.fromCharCode(...b));
const decode = (s: string) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
async function accountKey(secret: string, owner: string) {
  if (!secret || !owner) throw new Error("VAULT");
  const raw = decode(secret);
  if (raw.length !== 32) throw new Error("VAULT");
  const master = await crypto.subtle.importKey("raw", raw, "HKDF", false, [
    "deriveKey",
  ]);
  return crypto.subtle.deriveKey(
    {
      name: "HKDF",
      hash: "SHA-256",
      salt: utf8.encode(owner),
      info: utf8.encode("fluent-gemini-v1"),
    },
    master,
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt", "decrypt"],
  );
}
export async function sealKey(value: string, owner: string, secret: string) {
  const key = await accountKey(secret, owner),
    iv = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv, additionalData: utf8.encode(owner) },
    key,
    utf8.encode(value),
  );
  return "v1." + encode(iv) + "." + encode(new Uint8Array(ciphertext));
}
export async function openKey(value: string, owner: string, secret: string) {
  try {
    const [version, iv, encrypted] = value.split(".");
    if (version !== "v1" || !iv || !encrypted) throw new Error();
    const key = await accountKey(secret, owner);
    const raw = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv: decode(iv), additionalData: utf8.encode(owner) },
      key,
      decode(encrypted),
    );
    return new TextDecoder().decode(raw);
  } catch {
    throw new Error("VAULT");
  }
}
