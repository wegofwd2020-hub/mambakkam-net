import { z, defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';

const metadataDefinition = () =>
  z
    .object({
      title: z.string().optional(),
      ignoreTitleTemplate: z.boolean().optional(),

      canonical: z.string().url().optional(),

      robots: z
        .object({
          index: z.boolean().optional(),
          follow: z.boolean().optional(),
        })
        .optional(),

      description: z.string().optional(),

      openGraph: z
        .object({
          url: z.string().optional(),
          siteName: z.string().optional(),
          images: z
            .array(
              z.object({
                url: z.string(),
                width: z.number().optional(),
                height: z.number().optional(),
              })
            )
            .optional(),
          locale: z.string().optional(),
          type: z.string().optional(),
        })
        .optional(),

      twitter: z
        .object({
          handle: z.string().optional(),
          site: z.string().optional(),
          cardType: z.string().optional(),
        })
        .optional(),
    })
    .optional();

const postCollection = defineCollection({
  loader: glob({ pattern: ['*.md', '*.mdx'], base: 'src/data/post' }),
  schema: z.object({
    publishDate: z.date().optional(),
    updateDate: z.date().optional(),
    draft: z.boolean().optional(),

    title: z.string(),
    excerpt: z.string().optional(),
    image: z.string().optional(),

    category: z.string().optional(),
    tags: z.array(z.string()).optional(),
    author: z.string().optional(),

    metadata: metadataDefinition(),
  }),
});

const landmarkCollection = defineCollection({
  loader: glob({ pattern: ['*.md', '*.mdx'], base: 'src/data/landmarks' }),
  schema: z.object({
    name: z.string(),
    nameTamil: z.string().optional(),

    type: z.enum(['temple', 'water-body', 'historical', 'natural', 'community']),

    description: z.string(),
    excerpt: z.string().optional(),

    image: z.string().optional(),
    images: z.array(z.object({ src: z.string(), alt: z.string().optional() })).optional(),

    location: z
      .object({
        lat: z.number().optional(),
        lng: z.number().optional(),
        description: z.string().optional(),
      })
      .optional(),

    status: z.enum(['active', 'under-construction', 'historical']).default('active'),

    constructionUpdates: z
      .array(
        z.object({
          date: z.date(),
          note: z.string(),
        })
      )
      .optional(),

    publishDate: z.date().optional(),
    draft: z.boolean().optional(),

    metadata: metadataDefinition(),
  }),
});

const peopleCollection = defineCollection({
  loader: glob({ pattern: ['*.md', '*.mdx'], base: 'src/data/people' }),
  schema: z.object({
    name: z.string(),
    nameTamil: z.string().optional(),

    role: z.string(),
    bio: z.string(),

    image: z.string().optional(),

    stats: z
      .array(
        z.object({
          value: z.string(),
          label: z.string(),
        })
      )
      .optional(),

    work: z
      .array(
        z.object({
          title: z.string(),
          description: z.string(),
          url: z.string().url().optional(),
        })
      )
      .optional(),

    links: z
      .object({
        website: z.string().url().optional(),
        github: z.string().url().optional(),
        linkedin: z.string().url().optional(),
        instagram: z.string().url().optional(),
        twitter: z.string().url().optional(),
      })
      .optional(),

    featured: z.boolean().default(false),
    publishDate: z.date().optional(),
    draft: z.boolean().optional(),

    metadata: metadataDefinition(),
  }),
});

const workCollection = defineCollection({
  loader: glob({ pattern: ['*.md', '*.mdx'], base: 'src/data/work' }),
  schema: z.object({
    title: z.string(),
    excerpt: z.string(),

    author: z.string(), // matches person file slug e.g. 'siva-m'

    type: z.enum(['product', 'project', 'open-source', 'research']),
    status: z.enum(['live', 'in-progress', 'archived']).default('live'),

    url: z.string().url().optional(),
    landingUrl: z.string().optional(), // internal one-pager route (e.g. /thittam) — cards link here when set

    image: z.string().optional(),
    tags: z.array(z.string()).optional(),

    featured: z.boolean().default(false),
    comingSoon: z.boolean().default(false),
    listed: z.boolean().default(true), // set false to keep the detail page but hide it from work listings (/work + per-person)
    publishDate: z.date().optional(),
    draft: z.boolean().optional(),

    metadata: metadataDefinition(),
  }),
});

export const collections = {
  post: postCollection,
  landmarks: landmarkCollection,
  people: peopleCollection,
  work: workCollection,
};
