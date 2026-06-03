# Specs

> Optional but recommended. Use this for implementation detail that's too granular
> for PLAN.md: data models, API contracts, UI flows, business rules.
> Agents read this alongside PLAN.md during session start and epic decomposition.
>
> Delete sections you don't need. Add sections as decisions get made.

---

## Data Models

<!--
### User
- id: uuid, primary key
- email: string, unique, not null
- created_at: timestamp

### Post
- id: uuid, primary key
- author_id: uuid, foreign key → User
- body: text
- published: boolean, default false
-->

_TODO or delete this section_

---

## API Routes

<!--
POST   /api/auth/register     → { user, token }
POST   /api/auth/login        → { user, token }
GET    /api/posts             → Post[]
POST   /api/posts             → Post
GET    /api/posts/:id         → Post
DELETE /api/posts/:id         → 204
-->

_TODO or delete this section_

---

## UI Flows

<!--
### Onboarding
1. User lands on /
2. Clicks "Get Started"
3. Fills in name + email form
4. Redirected to /dashboard

### Creating a post
1. User clicks "New Post" from dashboard
2. Fills in body text
3. Clicks "Publish"
4. Post appears in feed immediately
-->

_TODO or delete this section_

---

## Business Rules

<!--
Constraints that must be enforced in code. Agents treat these as hard requirements.

- A user can only have one active session at a time
- Posts cannot be edited after 24 hours
- Email addresses must be verified before a user can post
-->

_TODO or delete this section_

---

## Environment Variables

<!-- List all env vars the app needs. Never put real values here — use .env.example.
     Agents use this list to know what to expect in the environment. -->

| Variable | Description | Required |
|---|---|---|
| | | |
