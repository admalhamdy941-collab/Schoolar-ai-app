import { AppShell } from "@/components/AppShell";

export const dynamic = "force-dynamic";

export default function HomePage() {
  const demoMode = !(process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY);
  return <AppShell demoMode={demoMode} />;
}
