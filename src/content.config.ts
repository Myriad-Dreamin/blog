import { glob } from "astro/loaders";
import { defineCollection, z } from "astro:content";

const blogFrom = (dir: string) =>
  defineCollection({
    // Load Typst files in the `content/article/` directory.
    loader: glob({ base: "./content/article" + dir, pattern: "*.typ" }),
    // Type-check frontmatter using a schema
    schema: z.object({
      title: z.string(),
      lang: z.string().nullable(),
      region: z.string().nullable(),
      author: z.string().optional(),
      description: z.any().optional(),
      date: z.coerce.date(),
      // Transform string to Date object
      updatedDate: z.coerce.date().optional(),
      tags: z.array(z.string()).optional(),
    }),
  });

const archive = defineCollection({
  // Load Typst files in the `content/article/` directory.
  loader: glob({ base: "./content/archive", pattern: "**/*.typ" }),
  // Type-check frontmatter using a schema
  schema: z.object({
    title: z.string(),
    author: z.string().optional(),
    description: z.any().optional(),
    date: z.coerce.date(),
    indices: z.array(z.string()).optional(),
    // Transform string to Date object
    updatedDate: z.coerce.date().optional(),
    tags: z.array(z.string()).optional(),
  }),
});

export const collections = {
  blog: blogFrom(""),
  "blog-zh": blogFrom("/zh"),
  "blog-en": blogFrom("/en"),
  archive,
};
