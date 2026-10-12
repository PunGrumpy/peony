const TOKEN = /\*\*[^*]+\*\*|`[^`]+`|\[[^\]]+\]\([^)\s]+\)/gu;
const SAFE_URL = /^(?:https:\/\/|\/)/u;

const renderToken = (token: string, key: string) => {
  if (token.startsWith("**")) {
    return <strong key={key}>{token.slice(2, -2)}</strong>;
  }
  if (token.startsWith("`")) {
    return <code key={key}>{token.slice(1, -1)}</code>;
  }
  const split = token.indexOf("](");
  const label = token.slice(1, split);
  const href = token.slice(split + 2, -1);
  return SAFE_URL.test(href) ? (
    <a key={key} href={href}>
      {label}
    </a>
  ) : (
    <span key={key}>{label}</span>
  );
};

export const renderInline = (text: string) => {
  const nodes = [];
  let cursor = 0;
  for (const match of text.matchAll(TOKEN)) {
    const start = match.index;
    if (start > cursor) {
      nodes.push(<span key={`${cursor}`}>{text.slice(cursor, start)}</span>);
    }
    nodes.push(renderToken(match[0], `${start}`));
    cursor = start + match[0].length;
  }
  if (cursor < text.length) {
    nodes.push(<span key={`${cursor}`}>{text.slice(cursor)}</span>);
  }
  return nodes;
};
