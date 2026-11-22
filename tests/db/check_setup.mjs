import {PGlite} from './node_modules/@electric-sql/pglite/dist/index.js';
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const db=new PGlite();
try {
 await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE SCHEMA auth;
 CREATE TABLE auth.users(id uuid primary key, phone text, email text);
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS 'SELECT NULL::uuid';`);
 await db.exec(readFileSync('db/setup_all.sql','utf8').replace(/^\uFEFF/,''));
 const result=await db.query("SELECT count(*)::int AS tables, bool_and(rowsecurity) AS all_rls FROM pg_tables WHERE schemaname='public'");
 assert.equal(result.rows[0].tables,15);
 assert.equal(result.rows[0].all_rls,true);
 console.log(result.rows);
 await assert.rejects(()=>db.exec(readFileSync('db/setup_all.sql','utf8').replace(/^\uFEFF/,'')));
 await db.exec('ROLLBACK');
 console.log('PASS: 15 tables with RLS; repeat application rejected without deleting existing tables.');
} finally {await db.close();}
