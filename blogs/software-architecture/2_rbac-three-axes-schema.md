---
permalink: /blogs/software-architecture/rbac-three-axes-schema
layout: post
title: Three Axes — Tenant, Module, Hat
---

> Part 2 of 3 — _A series on multi-tenant, multi-module, multi-hat access control._
> Previously: [Where RBAC Breaks](/blogs/software-architecture/where-rbac-breaks) · Next: [Beyond Roles: Polymorphic Onboarding and the Capability Matrix](/blogs/software-architecture/polymorphic-onboarding-capability-matrix) (coming up)

### Where we left off

In Part 1 we met Maya, who runs Sage Studios, a small chain with three locations. Each runs a salon, a spa, and a retail counter. We watched her run into the limits of single-role-per-user RBAC within five minutes of onboarding. The receptionist who also helps at retail. The senior stylist who occasionally covers the spa. The owner who still cuts hair on Tuesdays.

We diagnosed the underlying issue. The software collapsed three independent dimensions into one column called `role_id`. There's the business, the services within, the people who wear different hats in different services. Single-role-per-user can only express one of these. The cracks all came from the other two leaking out.

In this part we build the schema that doesn't lie. We'll look at three options that are tempting and one that wins. Schema is the foundation for everything that follows: the API surface, the authentication path, the user interface. Get this part right and the rest falls out cleanly.

### Three things, not one

Here's the shift in framing.

Stop thinking "what role does this user have." Start thinking "what role does this user have **in each thing they operate in**."

A user has a *membership* in a business. The membership says one thing: yes, this person belongs to this organization. The membership carries identity (name, email) and lifecycle (invited, active, suspended). Crucially, it does NOT carry a role.

Roles attach to the membership separately, one per module the user operates in. Anjali's membership has a Receptionist role attached for the salon, a Cashier role attached for retail, and nothing attached for the spa. That's the actual shape of her job. The data structure should hold it without simplification.

This pattern shows up under various names in the literature. Polymorphic role assignment. Scoped roles. Per-module RBAC. We're going to call it the three axes, because that's how the model thinks about itself.

The three axes are:

1. **Tenant**: the business unit a person belongs to. One row per (person, business).
2. **Module**: a grouping of permissions inside a tenant. Salon. Spa. Retail. Plus a special org-level scope for things that span everything (billing, team management, settings).
3. **Hat**: the role a person plays inside one specific module. Stylist in the salon. Cashier in retail. Nothing in the spa.

A person is one membership of a tenant (axis 1), with a hat per module they operate in (axes 2 and 3 combined).

### A small vocabulary, used the same way for the rest of the post

Three terms we'll use repeatedly. They're not new ideas, just consistent labels.

A **role** is a named bundle of permissions. Like before. But now each role carries the module it belongs to. "Stylist" has `module_key='salon'`. "Cashier" has `module_key='retail'`. "Owner" has `module_key=NULL` because it's an org-level role, not specific to a module.

A **membership** is the link between a person and a business. One row per person per tenant.

An **assignment** is what attaches a role to a membership. One assignment per (person, module they operate in).

If you squint at the existing schema you'd ship by default, the `role_id` column on the membership table is silently doing the job of the assignments table. The whole game is to lift it out.

### Schema attempt 1: what was already there

This is the baseline. The `role_id` lives on `tenant_users`.

```sql
tenant_users (
  id, tenant_id, user_id, role_id, created_at
)

roles (
  id, tenant_id, module_key, name, permissions[]
)
```

This works for Maya's earliest team setup, before anyone wears two hats. As soon as Anjali shows up needing two roles, this can't help. There's nowhere to put the second one.

So we need somewhere. The interesting question is where.

### Schema attempt 2: an array of role IDs

The first thing most engineers reach for is to widen the column.

```sql
tenant_users (
  id, tenant_id, user_id, role_ids uuid[], created_at
)
```

This works, in the strict sense that the column can hold multiple values. Anjali gets `[receptionist_id, cashier_id]`. Schema migration is one ALTER. Done.

You'll regret it. Three reasons.

PostgreSQL arrays don't get foreign key enforcement on individual elements. If a role is deleted, the array doesn't notice; you're left with stale references. You'd have to write a trigger that scans every membership row whenever a role gets deleted, or accept that array elements can be invalid pointers.

You can't enforce "one role per module" with this shape. Maya could end up with `[stylist_id, senior_stylist_id]` for one membership, both belonging to the salon module. Which one wins when computing the permission union? The schema is happy with the inconsistency. You'd have to validate at the application layer, every time you write to it.

Querying gets gnarly. "Show me all members with a role in the spa module" needs an unnest of the array joined against `roles`. Possible. Awkward in every ORM. Slow without a GIN index. "Show me everyone with the Stylist role" is the same pain. Both queries are common; both should be cheap.

The "array of role_ids" shape is sometimes correct for very simple, low-stakes internal tools. For a B2B product where roles gate every API call, it's the wrong shape.

Reject.

### Schema attempt 3: multiple membership rows per user

The second instinct is to keep the row-per-membership shape but allow multiple rows per user-tenant pair, one per module.

```sql
tenant_users (
  id, tenant_id, user_id, role_id, module_key, created_at,
  UNIQUE (tenant_id, user_id, module_key)
)
```

Anjali becomes two rows. One for the salon (with the receptionist role). One for retail (with the cashier role). The unique constraint enforces one role per module. Foreign keys stay simple. Querying is fine.

The conceptual model is the problem.

What does a "membership" mean now? Is it the fact that Anjali belongs to Sage Studios? Or is it the fact that Anjali has a specific role in a specific module? The shape says it's the latter. Anjali has *two memberships*, parallel to each other.

That's wrong. Anjali has one membership. She belongs to Sage Studios as one human, not as two parallel humans. Her name, her email, her invited-at and accepted-at timestamps belong to the person-belongs-to-tenant concept, not to the role-in-module concept.

If you keep those columns on this row shape, you duplicate them across rows. If Anjali changes her last name, you update two rows. Same for status. Same for any new column you ever add.

If you split them into a parent table to deduplicate, congratulations, you've just discovered the junction-table shape we're building toward.

Some teams do go this route. It's not catastrophic. But it conflates two ideas that want to live separately and you'll feel that strain every time you add a feature that touches identity.

Reject.

### Schema attempt 4: the junction (winner)

Separate the membership from the role assignments cleanly.

```sql
tenant_users (
  id, tenant_id, user_id, status, invited_at, accepted_at,
  UNIQUE (tenant_id, user_id)
)

tenant_user_roles (
  id, tenant_user_id, role_id, module_key, created_at,
  UNIQUE (tenant_user_id, module_key)
)

roles (
  id, tenant_id, module_key, name, permissions[]
)
```

One table for the "person belongs to tenant" fact. A separate junction table for "person has role X in module Y." Roles unchanged from before, except now they're meaningful targets for the junction's foreign key.

The unique constraint on `tenant_user_roles` enforces one role per module per person. If you later want to allow multi-role-within-one-module (rare in practice), drop the unique. Most products don't need to.

The `module_key` on the junction is denormalized from `role.module_key`. You could leave it off and join through `roles` every time, but having it on the junction makes "show me all members in the salon" a one-table query and gives you a fast index for the most common module-scoped lookups. The cost is keeping the value in sync with the role's module_key. A trigger handles it. Or a small invariant in the application layer.

Let's see what Anjali, Priya, and Maya look like in this shape.

```
-- Anjali: receptionist in salon, cashier in retail
tenant_users:
  (id: anjali_membership, tenant_id: sage, user_id: anjali,
   status: active, invited_at: ..., accepted_at: ...)

tenant_user_roles:
  (tenant_user_id: anjali_membership, role_id: receptionist, module_key: salon)
  (tenant_user_id: anjali_membership, role_id: cashier,      module_key: retail)
```

```
-- Priya: senior stylist in salon, occasional spa cover
tenant_users:
  (id: priya_membership, tenant_id: sage, user_id: priya, status: active)

tenant_user_roles:
  (tenant_user_id: priya_membership, role_id: senior_stylist, module_key: salon)
  (tenant_user_id: priya_membership, role_id: spa_cover,      module_key: spa)
```

```
-- Maya: owner (org-level) plus senior stylist on Tue/Thu
tenant_users:
  (id: maya_membership, tenant_id: sage, user_id: maya, status: active)

tenant_user_roles:
  (tenant_user_id: maya_membership, role_id: owner,          module_key: NULL)
  (tenant_user_id: maya_membership, role_id: senior_stylist, module_key: salon)
```

Three people, three different shapes of multi-hat-ness, all expressed without the schema lying.

A person without a role in a module simply has no row in `tenant_user_roles` for that module. Anjali has no row for the spa module, so she has no spa access. The spa booking calendar doesn't list her. The spa permissions don't appear in her token. The absence of a row IS the no-access state. There's no `is_disabled` flag, no nullable role, no "role = none" sentinel. Just absence.

That's the schema. Forty lines of DDL. Everything else in the system follows from this shape.

### What this looks like at runtime

When Anjali logs in, the auth service has to figure out her permissions. With the old single-role model, it was one row read. With the junction, it's a small union.

```sql
SELECT DISTINCT unnest(r.permissions) AS permission
FROM tenant_user_roles tur
JOIN roles r ON r.id = tur.role_id
WHERE tur.tenant_user_id = $1
  AND (
    r.module_key IS NULL
    OR r.module_key IN (
      SELECT module_key
      FROM tenant_modules
      WHERE tenant_id = $2 AND enabled = true
    )
  );
```

Two filters carry the meaning.

The first joins through `tenant_user_roles` to gather all of Anjali's roles. The union of their permissions is what she can do.

The second filters out roles whose module is currently disabled at the tenant level. That second filter is the trick that lets Maya turn off the retail module without deleting Anjali's cashier role. The role stays. The cashier permissions become inert until retail is re-enabled, at which point they reactivate without anyone editing the assignment table. That's a quietly nice property of separating "does this person have the role" from "is the module currently turned on."

The result is the union of all permission strings across all of Anjali's active roles. That goes into her access token (JWT, session cookie, whatever you use). Every downstream API call checks against it the same way it always did.

The permission check at the call site doesn't change. `if (user.permissions.includes('retail:operate-till')) ...` works exactly as before. The schema change is invisible to the rest of your codebase, except for the page that lists members, the page that adds them, and the page that edits their roles. Every other surface is untouched.

That's worth pausing on. Schema migrations of this shape are cheap if you set up the join correctly. The blast radius is the team-management surface and the auth issue path. Everything else is the same code reading the same shape of permission list.

### Granular role lifecycle (the natural API)

The junction makes the API for managing roles clean.

To grant Anjali retail access, insert a row into `tenant_user_roles` with `(anjali_membership, cashier, retail)`. The unique constraint rejects if she already has a role in retail. To swap her cashier role for a manager role within retail, do an upsert. To revoke her retail access entirely, delete the row.

Each of those becomes a small, predictable endpoint:

- `POST /memberships/{id}/roles` — grant a role in a module
- `DELETE /memberships/{id}/roles/{role_id}` — revoke a role
- `PATCH /memberships/{id}/roles/{role_id}` — change a role within the same module

Three endpoints, each idempotent in its natural way, each expressing exactly the operation the user thinks they're doing. "Add Anjali to retail." "Remove Anjali from spa." Compare this to the single-role world, where "change role" was the only verb available, and that one verb couldn't carry "add a second role" or "remove only the spa role and keep the salon one."

The vocabulary the schema gives you matches the vocabulary your users have in their head. That's a sign you have the right shape.

### Migrating from the old shape

If you have data in the old single-role shape, the migration is uncomplicated. Expand-then-contract.

```sql
-- 1. Create the junction table.
CREATE TABLE tenant_user_roles ( ... );

-- 2. Backfill from existing single-role memberships.
INSERT INTO tenant_user_roles (tenant_user_id, role_id, module_key, created_at)
SELECT tu.id, tu.role_id, r.module_key, tu.created_at
FROM tenant_users tu
JOIN roles r ON r.id = tu.role_id;

-- 3. Application code reads from the junction. (Deploy this part before step 4.)

-- 4. Drop the old column.
ALTER TABLE tenant_users DROP COLUMN role_id;
```

Every existing single-role user becomes a single-row-in-junction user. Same access. Different shape. No data loss. The application reads from the new shape from then on.

The cutover happens in two parts. First, deploy the application code that reads from the junction (with a fallback to the old column for safety). Then run the backfill and remove the fallback. Standard expand-then-contract. Not exciting. That's the point.

The harder part of this migration isn't the SQL. It's the application code. Every place that reads `user.role` has to learn to read `user.roles`. Every place that writes `role_id` on a membership has to learn the new endpoints. Every UI that says "this user's role" has to start saying "this user's roles." That's a sweep, not a migration. We'll talk more about it in Part 3 when we look at the UI.

### Coming up

We have the schema. It expresses Maya's reality. It supports the granular role lifecycle the UI needs. It holds together for whatever modules Maya turns on or off in the future.

What it doesn't yet do is reach into the user experience and change how Maya thinks about adding people to her team. The schema can store "Stylist with calendar visibility and license number," but the dialog Maya sees still asks her in the wrong order, in the wrong combinations, with the wrong assumptions about who fills what.

In Part 3 we close the loop. Role-driven polymorphic onboarding (the dialog that asks different questions based on the role you pick). The split between what the owner fills at create-time and what the staff member fills themselves later. And the next layer above all of this for the rare cases where roles aren't fine-grained enough: the capability matrix.

That's where the system stops being a schema exercise and starts feeling like the product Maya thought she was buying.

---

> Part 3 (final): [Beyond Roles: Polymorphic Onboarding and the Capability Matrix](/blogs/software-architecture/polymorphic-onboarding-capability-matrix). Coming up.
