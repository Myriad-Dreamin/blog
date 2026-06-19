import { getCollection, type CollectionEntry } from "astro:content";

const blog = await getCollection("blog");
const blogEn = new Map((await getCollection("blog-en")).map((p) => [p.id, p]));
const blogZh = new Map((await getCollection("blog-zh")).map((p) => [p.id, p]));
const blogByLocale: Record<string, typeof blogEn | typeof blogZh> = {
  zh: blogZh,
  en: blogEn,
};

export interface LocaleInfo {
  canonical: string;
  availables: string[];
  data(locale?: string): CollectionEntry<"blog">["data"];
}

export function formatLang(lang?: string, region?: string) {
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
      data(locale?: string) {
        return blogByLocale[locale || "en"].get(post.id)?.data || post.data;
      },
    } satisfies LocaleInfo,
  ]),
);

export function getPostLocaleInfo(id: string) {
  const info = localeInfo.get(id);
  if (!info) {
    throw new Error(`Locale info for id "${id}" not found.`);
  }
  return info;
}
