---
permalink: /blogs/software-architecture/polymorphic-onboarding-capability-matrix
layout: post
title: "Beyond Roles: Polymorphic Onboarding and the Capability Matrix"
---

> Part 3 of 3. A series on multi-tenant, multi-module, multi-hat access control.
> Previously: [Where RBAC Breaks](/blogs/software-architecture/where-rbac-breaks), [Three Axes: Tenant, Module, Hat](/blogs/software-architecture/rbac-three-axes-schema).

### Where we are

Two parts in. We've watched Maya struggle with single-role-per-user onboarding, and we've built a junction-table schema that holds her reality without lying. We can express that Anjali is a receptionist in the salon and a cashier in retail, and that Maya is the owner who also cuts hair on Tuesdays.

The schema is honest about who's who, but Maya's first interaction with the software is still a form, and the form doesn't yet feel like the schema underneath. Different roles need different fields, the form should ask for them in the right order, and there are some things Maya simply doesn't know that the staff member themselves does. We need to close that loop.

We also need to talk about a layer above roles, for the rare cases when "Stylist" or "Cashier" isn't fine-grained enough.

This is the last part.

### The dialog Maya wishes she had

Imagine the smallest possible "add a team member" form.

```
┌─ Add staff ──────────────────────────────┐
│                                            │
│  Name                                      │
│  [_______________________________]         │
│                                            │
│  Email                                     │
│  [_______________________________]         │
│                                            │
│  Role                                      │
│  [ Stylist                       ▼ ]       │
│  ↳ Maya picks "Stylist" from a grouped     │
│    dropdown. Roles are grouped by module:  │
│    Organization, Salon, Spa, Retail.       │
│                                            │
│  ─────────────── (extras)                  │
│                                            │
│  Booking hours      [ 9 AM ]–[ 6 PM ]      │
│  Visible on calendar  [✓]                  │
│  Available for new appointments  [✓]       │
│                                            │
│         [ Cancel ]   [ Send invite ]       │
└────────────────────────────────────────────┘
```

Three always-fields at the top: name, email, role. The role picker is grouped, so Maya can see "Stylist" under Salon, "Cashier" under Retail, "Owner" under Organization. She picks one.

The interesting part is below the role picker. The form's tail changes shape based on which role she picked. If she picks Stylist, the form sprouts three more fields about booking visibility. If she picks Cashier, those go away and a different set appears, like till assignment. If she picks Receptionist, no extras at all. If she picks Owner, no extras and no operational tail because owners aren't operationally on a calendar.

Call this role-driven polymorphic onboarding. The form is the same form, with different "tails" depending on the role. Maya sees one dialog, fills three or four fields, hits Send. The system handles the rest behind the scenes.

### What "polymorphic" means here

Polymorphism in this context means the form has one well-defined skeleton (name, email, role), and a tail that's selected at runtime based on which role the user picked. Each module that contributes roles also contributes the form-tail those roles need.

Concretely, you'd have a small registry pattern. Each module's code declares: "if a role I own is picked, render this component for the extras."

```ts
// pseudocode — in your real app, types and module structure will differ
const roleProfiles = {
  salon: {
    extrasComponent: SalonStaffExtrasForm,
    onSubmit: createSalonEmployment,
  },
  retail: {
    extrasComponent: RetailStaffExtrasForm,
    onSubmit: createRetailEmployment,
  },
  spa: {
    extrasComponent: SpaStaffExtrasForm,
    onSubmit: createSpaEmployment,
  },
  // org-level roles have no profile, no extras, no operational record
};
```

When Maya picks a role, the dialog asks the registry: "do you have a profile for this role's module?" If yes, mount the extras component below the role picker, and on submit, run both the create-membership call and the module's `onSubmit` to set up the operational record (the booking calendar entry, the till assignment, whatever).

If no profile is registered (org-level role like Owner or Admin, or a module without operational records like an NGO membership module), the form has no tail. Submit just creates the membership. The module-specific orchestration happens automatically based on the role's `module_key` from Part 2.

The shape of this is small. A few hundred lines of code total once you have it set up. New modules plug in by registering a profile. Zero changes to the core dialog when a new module shows up.

### Who fills what

There's a question worth asking before you start putting fields in the form. What does Maya, the owner, actually know when she sits down to onboard a new stylist?

She knows their name, their email, what role they're going to play, and probably their working hours, because she's the one scheduling them.

Here's what she does not know. She doesn't know Priya's stylist license number. That number is on Priya's certificate, in Priya's wallet. Maya could ask, but Priya is starting next Monday, and asking now means a phone call and a wait. She doesn't know Priya's bio for the public profile, because Priya hasn't written one yet. She doesn't know Priya's photo, because Priya hasn't sent one.

If the onboarding form asks for these things, Maya is blocked. She either makes something up (license number 0000?), skips fields and leaves the staff record incomplete in ways she has to come back and fix, or abandons the whole onboarding and tells herself she'll come back to it later. All three are bad outcomes for adoption.

A pattern that works much better: the owner fills operational policy at create time, and the staff member fills personal data themselves, after first login. (Some HR products call this stub-then-self-complete.)

Operational policy is what Maya genuinely knows and has the authority to decide. Booking hours, calendar visibility, whether this person is available for appointments at all, the till PIN for the cashier. The module-specific operational stuff lives in this bucket.

Personal data is what only the staff member can authoritatively provide. License number, bio, photo, future certifications, personal contact preferences. These live in the staff member's own profile, which they fill themselves the first time they log in.

The owner sees a "profile pending" indicator on the staff list (a small badge, maybe a count on the dashboard) for any staff who haven't completed their personal data yet. The owner can override-fill if they happen to have the data on paper, but it's not the default expectation.

This split is what makes the onboarding form feel quick. The form is three fields plus a small operational tail, the owner is unblocked, and the staff member completes their own stuff on their own time. Nobody is waiting on someone else for data they don't own.

### When roles aren't enough

Most of what we've described works because roles are good abstractions. "Stylist" bundles a coherent set of permissions; "Cashier" bundles a different coherent set. A new person joins, you pick the role that fits, and you're done.

Sometimes that doesn't fit. Maya's admin handles billing for all three locations. She also wants the admin to occasionally see audit logs, because she's helping with a compliance review. The admin's "Admin" role doesn't include `audit_logs:read` by default. Maya doesn't want to promote the admin to Owner just for this, and she doesn't want to create a custom role called "Admin Plus Audit Logs" for one person. She just wants to grant one permission to one person, override-style.

This is where the capability matrix comes in. It's a layer that sits above roles. It doesn't replace roles; it augments them. The schema looks roughly like this:

```sql
tenant_user_capabilities (
  tenant_user_id, permission, granted_at, granted_by,
  PRIMARY KEY (tenant_user_id, permission)
)
```

For each membership, you can grant individual permissions that are added on top of whatever the membership's roles already grant. Revoke works the same way. Grant `audit_logs:read` to the admin's membership, and the admin gets that one permission in addition to their normal Admin bundle.

At runtime, the permission union becomes:

```
permissions = (union of all role permissions) ∪ (per-user granted permissions)
```

To make that concrete, here is what Maya's admin looks like once `audit_logs:read` is granted as an override:

| Source            | billing:read | billing:write | users:invite | audit_logs:read |
| ----------------- | :----------: | :-----------: | :----------: | :-------------: |
| From "Admin" role |       ✓      |       ✓       |       ✓      |        —        |
| Override grant    |       —      |       —       |       —      |        ✓        |
| **Effective**     |     **✓**    |     **✓**     |     **✓**    |      **✓**      |

The "Effective" row is the column-wise OR of the two rows above it. Roles do most of the work, overrides fill in the one cell they couldn't reach, and the union is what ends up in the access token. Reading down a single column tells you why a permission is or isn't granted, which is the question that comes up the moment something doesn't work in production.

This is the capability matrix as an additive override. You can also build it as a subtractive override, where individual permissions are revoked from a role's default bundle. Most teams find additive cleaner.

When should you build this layer? Probably not at the start. Most products go years without needing it, and adding it as a future evolution is much cheaper than building it on day one and never using it. The schema is small (one table), the runtime is small (one extra union). The UI is the heavy part: per-user permission overrides need a clear, scannable matrix view, and that's a real design problem.

When you do build it, you'll know. There'll be a customer support ticket that goes "I want this one person to also be able to see X, but they're not Admin." When you find yourself creating a custom role for one person, that's the signal.

A few products that have this layer: Salesforce ("permission sets" are exactly this), Atlassian Cloud (the platform-wide products do similar), GitHub (organization-level roles plus repo-level permission grants). They didn't all start with the matrix; most added it once their roles couldn't carry the load.

### The capability matrix isn't multi-hat

A small clarification, because this confuses people.

Multi-hat (Part 2) is "this person operates in multiple modules, with one role in each." The schema for it is the junction table. The capability matrix is "this person's role in a specific module isn't quite right, grant them one extra permission as an override." The schema for it is a separate table of per-membership permission grants.

You can ship the junction without the matrix, and you probably should. Multi-hat is a frequent need in any product with multiple modules, the day you onboard the first staff member who works across them. The capability matrix is rare; you'll know when you need it. They live at different layers of the same architecture.

### Some opinions

Two parts of architecture and one part of UX. Closing with what I actually believe about all of this.

If you're building B2B SaaS with the slightest chance of becoming a multi-module platform, design for the three-axis schema from day one. The single-role-per-user shape is correct for very simple products, but as soon as you have two modules under one roof, or staff who wear multiple hats, or a customer who runs a chain, it collapses. The migration is mechanically simple, but the *product* migration is expensive: you're rewriting the team-management UI, retraining users, explaining to your support team why the new model exists. Pay it once at the beginning instead.

Ship for one module's worth of customers but design the schema for ten. Most products will only have one or two modules for years, and that's fine. The schema doesn't cost more once you've drawn it on the whiteboard. Build the junction table even if `tenant_user_roles` only ever has one row per membership in your first six months. The one-row-per-membership case is a degenerate case of the general shape, not a different shape. You aren't paying for capability you don't use; you're declining to lock yourself out of capability you'll definitely need.

Don't build the capability matrix on day one. It's a real layer with real value, but its value is rare and the UX for it is genuinely hard to do well. Wait for the support tickets that say "I want this one user to also have this one permission, and not be Admin." When you have three of those tickets, you have your justification. Until then, the capability matrix adds complexity without earning its keep.

Make onboarding quick and forgiving. This is the smallest piece of advice and the one that pays back the most in adoption. Three fields, a role-driven tail, send. The split between owner-fills and staff-fills is what makes this possible. Don't ask the owner for things they don't know, and don't block the form on data only the staff member has. The polymorphic-onboarding pattern is small to implement, and the customer feedback is immediate.

Treat module access as data, not as code. The thing that lets you turn modules on and off, scope role pickers by module, group permissions by module, and grant access per module is that *modules* themselves are first-class data in your system. You have a `modules` table (or a `tenant_modules` table for which modules are enabled per tenant). Modules are not feature flags, they're the structural unit your permissions and roles attach to. Get this right and the rest of the system has somewhere to anchor.

The schema will outlive the UI. Whatever onboarding form you ship today, the schema underneath it will probably still be there in five years, while the form has been redesigned three times. The form is what users see; the schema is what the form is allowed to ask for. Get the schema right first.

### Sign-off

Three parts. Maya, her three locations, her staff who wear different hats in different services. The schema that holds it, the form that uses it, the capability matrix as an evolutionary next step.

What started as a small bug in Maya's first onboarding ("add Priya as staff" when she just added Priya) was actually pointing at a deep model mismatch. Once you see the three axes (tenant, module, hat), most B2B RBAC pain looks the same shape. Notion has it, GitHub has it, and Slack has it under the hood as Enterprise Grid. The architecture is consistent enough that once you've built it once, you recognize it everywhere.

If you're at the start of a product that might one day look like Sage Studios, this is the shape to aim for. If you're already past the start and the cracks are showing up, the migration isn't terrifying. The shape is there waiting for you.

Thanks for reading. If any of this lands wrong, or if you've shipped a different shape that solved similar problems, I'd love to know.

---

> End of series. Back to the start: [Where RBAC Breaks](/blogs/software-architecture/where-rbac-breaks).
