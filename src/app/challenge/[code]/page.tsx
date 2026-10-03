import { ChallengeArena } from "@/components/ChallengeArena";

export const dynamic = "force-dynamic";

export default async function ChallengePage({ params }: { params: Promise<{ code: string }> }) {
  const { code } = await params;
  return <ChallengeArena code={code.toUpperCase()} />;
}
