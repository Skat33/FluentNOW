import Fluent from "./fluent";
import { getChatGPTUser } from "./chatgpt-auth";
export const dynamic = "force-dynamic";
export default async function Page() {
  const user = await getChatGPTUser();
  return (
    <Fluent
      user={
        user ? { name: user.fullName || "Odkrywca", email: user.email } : null
      }
    />
  );
}
