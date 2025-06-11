import { getCollection } from "astro:content";

const blog = await getCollection("blog");
const blogEn = new Map((await getCollection("blog-en")).map((p) => [p.id, p]));
const blogZh = new Map((await getCollection("blog-zh")).map((p) => [p.id, p]));

export interface LocaleInfo {
  canonical: string;
  availables: string[];
}

export function formatLang(lang: string | null, region: string | null) {
  return lang && region ? `${lang}-${region.toUpperCase()}` : lang || "en";
}

const localeInfo = new Map(
  blog.map((post) => [
    post.id,
    {
      canonical: post.data.lang || "en",
      availables: [
        ...((blogEn.get(post.id)?.data.lang || post.data.lang) == "en"
          ? ["en"]
          : []),
        ...((blogZh.get(post.id)?.data.lang || post.data.lang) == "zh"
          ? ["zh"]
          : []),
      ],
    } satisfies LocaleInfo,
  ])
);

export function getPostLocaleInfo(id: string) {
  const info = localeInfo.get(id);
  if (!info) {
    throw new Error(`Locale info for id "${id}" not found.`);
  }
  return info;
}
