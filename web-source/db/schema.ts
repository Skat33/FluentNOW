import {sqliteTable,text,integer,index} from 'drizzle-orm/sqlite-core';
// One atomic, versioned learning aggregate per authenticated owner.
// Meaning IDs are stable; each meaning contains independent skill records.
export const learners=sqliteTable('learners',{
 owner:text('owner').primaryKey(),
 content:text('content').notNull(),
 revision:integer('revision').notNull().default(0),
 updatedAt:integer('updated_at').notNull(),
});

export const tutorUsage=sqliteTable('tutor_usage',{
 owner:text('owner').primaryKey(),day:text('day').notNull(),count:integer('count').notNull().default(0)
});

export const geminiConnections=sqliteTable('gemini_connections',{owner:text('owner').primaryKey(),encryptedKey:text('encrypted_key').notNull(),model:text('model').notNull(),speechModel:text('speech_model')});

export const topicCache=sqliteTable('topic_cache',{
 topicKey:text('topic_key').primaryKey(),payload:text('payload').notNull(),created:integer('created').notNull()
});

// Shared tables contain reusable language content only. Never store a learner's
// State, vocabulary ownership, settings, review history, profile or results here.
export const sharedContent=sqliteTable('shared_content',{
 cacheKey:text('cache_key').primaryKey(),
 kind:text('kind').notNull(),
 canonical:text('canonical').notNull(),
 payload:text('payload').notNull(),
 model:text('model').notNull(),
 promptVer:integer('prompt_ver').notNull(),
 created:integer('created').notNull(),
 refreshed:integer('refreshed').notNull(),
 hits:integer('hits').notNull().default(0),
},(table)=>[index('shared_content_kind_hits').on(table.kind,table.hits)]);

export const sharedAliases=sqliteTable('shared_aliases',{
 alias:text('alias').primaryKey(),
 cacheKey:text('cache_key').notNull(),
 category:text('category'),
 source:text('source').notNull(),
 created:integer('created').notNull(),
 hits:integer('hits').notNull().default(0),
});

export const sharedResolutionLog=sqliteTable('shared_resolution_log',{
 id:integer('id').primaryKey({autoIncrement:true}),
 query:text('query').notNull(),
 normalized:text('normalized').notNull(),
 layer:text('layer').notNull(),
 cacheKey:text('cache_key'),
 created:integer('created').notNull(),
});

// Durable sentence bank, never subject to cache TTL. A lease serializes all batches
// for one concrete meaning/context, including requests from different accounts.
export const examplePools=sqliteTable('example_pools',{
 poolKey:text('pool_key').primaryKey(),scope:text('scope').notNull(),
 descriptor:text('descriptor').notNull(),payload:text('payload').notNull().default('{}'),
 leaseToken:text('lease_token'),leaseUntil:integer('lease_until').notNull().default(0),
 updated:integer('updated').notNull(),
});

export const exerciseReports=sqliteTable('exercise_reports',{
 id:text('id').primaryKey(),owner:text('owner').notNull(),payload:text('payload').notNull(),
 status:text('status').notNull().default('pending'),created:integer('created').notNull(),updated:integer('updated').notNull(),
 reason:text('reason').notNull().default(''),runToken:text('run_token'),retryAt:integer('retry_at').notNull().default(0),
},t=>[index('reports_owner_created').on(t.owner,t.created),index('reports_status_retry').on(t.status,t.retryAt)]);
export const reportCorrections=sqliteTable('report_corrections',{
 id:text('id').primaryKey(),owner:text('owner').notNull(),targetKey:text('target_key').notNull(),payload:text('payload').notNull(),updated:integer('updated').notNull(),
},t=>[index('corrections_owner').on(t.owner)]);
export const reportRuns=sqliteTable('report_runs',{
 id:text('id').primaryKey(),token:text('token').notNull(),started:integer('started').notNull(),leaseUntil:integer('lease_until').notNull(),nextRun:integer('next_run').notNull(),
});
