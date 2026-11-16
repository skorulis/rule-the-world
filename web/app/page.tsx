import Link from "next/link";

export default function Page() {
  return (
    <main>
      <h1>Rule The World API</h1>
      <Link href="/health">Health check</Link>
    </main>
  );
}
