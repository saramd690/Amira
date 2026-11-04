# Amira — Candidate Portal

Candidate profile, CV management, and candidate dashboard built with Next.js App Router, TypeScript, and Supabase.

## Requirements

- Node.js 22 or newer
- A Supabase project with the migrations in `supabase/migrations` applied

## Local setup

1. Copy `.env.example` to `.env.local`.
2. Set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`.
3. Install and run:

```bash
npm install
npm run dev
```

Useful checks:

```bash
npm run typecheck
npm test
npm run build
```

## Supabase Auth configuration

Add the local and deployed application callback URLs to Supabase Auth's allowed redirect URLs, for example:

- `http://localhost:3000/auth/callback`
- `https://YOUR_DOMAIN/auth/callback`

Set the Auth Site URL to the deployed application origin. Configure the confirmation and password recovery email templates to return to the callback route.

## Features

- Candidate sign-up, sign-in, email confirmation callback, password recovery, and sign-out
- Profile, education, experience, languages, certificates, and projects
- Profile completion calculated in PostgreSQL
- Private PDF/DOCX CV uploads, version history, active version switching, preview, download, and delete
- Availability status and change history
- Candidate privacy preferences
- Dashboard mock data for skills, applications, recommendations, and interviews

## Security

All candidate tables use RLS ownership policies. The CV bucket is private and object policies scope access to the authenticated user's folder. API handlers derive the owner from the verified Supabase session; client-supplied owner IDs are ignored.

Recruiter/public profile access is deliberately not enabled. Privacy preferences are stored, but they do not grant external access until a separate recruiter identity, consent, and authorization model is implemented.

Never put Supabase service-role or secret keys in `NEXT_PUBLIC_*` variables or commit them to the repository.

## Documentation

See [Arabic system documentation](docs/candidate-system-ar.md).
