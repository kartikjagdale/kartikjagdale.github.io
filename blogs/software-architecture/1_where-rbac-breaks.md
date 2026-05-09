---
permalink: /blogs/software-architecture/where-rbac-breaks
layout: post
title: "Where RBAC Breaks: A Small-Business Story"
---

> Part 1 of 3. A series on multi-tenant, multi-module, multi-hat access control.
> Next: [The three axes: tenant × module × hat](/blogs/software-architecture/rbac-three-axes-schema) (coming up)

### Meet Maya

Maya runs Sage Studios, a small chain with three locations across the city. Each location has a salon (haircuts and color), a spa (facials, massage, body treatments), and a small retail counter selling hair and skin products. About fifteen people work for her: stylists, therapists, receptionists, a cashier here and there, an admin who keeps the books.

The day Maya signed up for her shiny new business management software, she sat down with a cup of chai and started adding her team. Name, email, role, send invite.

Five minutes later she was confused.

She'd added Priya as a stylist, then went to put Priya on the salon's booking calendar. The software told her she needed to add Priya as staff. But Maya had just added her as a stylist, and surely a stylist is staff?

She clicked into "Staff." A different page, a different button, a different form. She picked Priya from a list, and a panel appeared asking for booking hours, calendar visibility, and whether Priya was "available for appointments." Maya filled it in, hit save, and went back to work.

Then she remembered Anjali, her receptionist who also helps at the retail counter on Saturdays. She stared at the role dropdown. Anjali was a *receptionist*, but Anjali also did *retail*. The system would only let her pick one.

Maya figured her onboarding had a small bug. She'd email support tomorrow.

### What is "role-based access," really?

Before we go further, a quick definition. Role-based access control (RBAC, if you've seen the acronym) is simpler than it sounds.

A *permission* is a single thing a user is allowed to do: "edit the booking calendar," "view invoices," "delete a customer." Each is a tiny on/off switch, usually a string like `bookings:edit` or `invoices:read` in code.

A *role* is a bundle of permissions you give a name to. "Stylist" might bundle `appointments:read`, `appointments:create`, `customer:view`, `services:read`. "Owner" bundles everything. "Receptionist" bundles a different set.

That's the whole concept. Roles are labels you stick on bundles of switches so you don't have to flip every switch one-by-one when a new person joins.

Most software you've used implements RBAC this way. Notion has Owner, Member, Guest. GitHub has Admin, Maintainer, Developer, Triage. Slack has Workspace Owner, Admin, Member. All variations on the same theme: pick a role, pick a bundle. It works fine until your reality stops being one product, one team, one role per person.

### Why the simple version works fine at first

Here's the version of access control most software ships with on day one. There's a `users` table. Each user has a `role` column, or maybe a `role_id` pointing at a small `roles` table. To check whether a user can do something, you look up their role and check if the permission is in their bundle.

```sql
-- The everyday version of RBAC
users (
  id, email, name, role_id
)

roles (
  id, name, permissions[]
)
```

If you're building software for a single product where every user does roughly the same kind of thing, this is correct. Adding more complexity than you need is a worse mistake than starting too simple. The trouble starts when "the same kind of thing" stops being singular.

### The first crack: same person, two jobs

Anjali is the receptionist. That's her primary job, greeting customers at the front desk of the salon. But on Saturdays, when retail gets busy, she helps at the till for an hour.

In Maya's RBAC software, Anjali has one role: Receptionist. Her permission bundle includes `customer:view`, `appointments:create`, `bookings:read`. It doesn't include `retail:operate-till`. So when Anjali tries to ring up a sale on Saturday, the software says no.

Maya now has three options, each bad. She can change Anjali's role to Cashier on Saturdays and back to Receptionist on Monday, which is fragile and easy to forget. She can create a custom role called "Receptionist + Cashier" that bundles both, which works once but doesn't scale to thirty staff with thirty slightly-different overlap patterns. Or she can promote Anjali to Owner so she can do everything and trust her not to delete things, which is the YOLO option, and terrible for security.

All three are symptoms of the same diagnosis. The system assumes Anjali has one job, and Anjali has two.

### The second crack: the new module no one planned for

Six months in, Maya signs up for a new feature in her software: appointment scheduling for the spa. Until now her spa was running off pen-and-paper. Now there's a digital booking calendar for the spa, just like the salon's.

The software adds a new section called Spa, with its own staff list, its own bookings, its own pricing.

Maya's salon stylists don't operate in the spa, mostly. But Priya, Maya's senior stylist, sometimes covers the spa massage room when the regular massage therapist is out. So Priya needs to appear on the spa booking calendar too, just occasionally.

In Maya's RBAC software, Priya has one role: Senior Stylist. That role gave her access to everything in the salon but says nothing about the spa.

Maya goes to add Priya to the spa. The software wants Priya to have a *spa role* and offers her "Spa Therapist." But Priya isn't a Spa Therapist; she's a Stylist who covers the spa. There's no "Stylist who also does spa" in the dropdown. Maya improvises and picks "Spa Therapist" anyway.

Now Priya appears on both calendars. Maya's two boards overlap each other strangely, and sometimes a salon client and a spa client get double-booked into Priya's slot, because the system thinks of Priya as one staff member with two parallel roles but doesn't connect their schedules. The system has been pushed past its design.

### The third crack: the owner who's also a stylist

Maya isn't just the owner. She's also a senior stylist, and still cuts hair on Tuesdays and Thursdays. She wants her name on the salon booking calendar for those days.

But the software has her listed as Owner, the role that gives her permission to do everything in the system. Not as a Stylist. Owners don't appear on the booking calendar by default.

Maya tries to give herself a second role. The software politely says: a person can only have one role.

You can see where this is going.

### The deeper diagnosis

We could keep going. The admin who handles billing across all three locations. The cashier who covers retail at one location but not the others. The freelance massage therapist who works at all three locations, two days a week each. Each is a flavor of the same problem.

The diagnosis is this: the software was built around a single concept of "what kind of person is this user," and Maya's reality has three concepts braided together. There's the business (Maya's chain), there are the services within the business (salon, spa, retail), and there are the people, each with their own combination of which services they work in and what they do there. The software collapsed all three into one column called `role_id`, and now it can't carry the weight.

It isn't a bug or bad code. It's a model that fits the simpler reality of one product, one team, one role-per-person, and Maya's small business is more complex than that.

### Why this matters before you've shipped

If you're building B2B SaaS, more of your customers will look like Maya than not. You'll hit this the day a customer asks if their staff member can have two roles, or the day you add a second product surface (a "module," in this series' language) under your platform.

The single-role version is genuinely correct for very simple realities, and you don't need to over-engineer day one. But you do need to know what shape the next version takes before the cracks force a hasty migration. Access control is one of those parts of a system where a hasty migration is genuinely painful: every page in your product reads from it, every API call enforces it, every audit trail records it.

The good news is that the next version isn't very different. Same basic idea (roles bundle permissions) with one shift in axis. We'll see in part 2.

### A preview, in simple terms

Imagine Maya's reality as three independent dimensions:

1. The business she's running, Sage Studios. (One business per *tenant*, in software terms.)
2. The services within it: salon, spa, retail. (Each is a *module*.)
3. The people, each with their own combination of where they work and what they do there. (Each can wear multiple *hats*.)

Traditional RBAC tries to express all three with one column. We'll express them with three. The schema follows from there, and so does the user experience and the capability matrix for cases where roles aren't fine-grained enough. Onboarding stops being a tug-of-war between "add user" and "add staff," and Maya stops getting confused on day one.

### What we're not solving

A few things this series isn't about, so you don't read it expecting them.

We're not building fine-grained per-row authorization, the "this user can read THIS document but not that one" problem. Tools like Oso, OpenFGA, and SpiceDB exist for that and they're great. The problem here is the broader-shape one: how roles compose across multiple apps in one platform, which is most B2B RBAC pain.

We're not designing OAuth scopes or API token permissions, which is a parallel concern. The roles we'll build are for human users inside a tenant.

And we're not arguing about RBAC vs ABAC vs ReBAC as the underlying model. RBAC, the way most software ships it, is good enough for most B2B SaaS most of the time. The point is to show how it scales, not to advocate for a paradigm shift.

Tea break. See you in part 2.

---

> Coming next: [Part 2: The three axes — tenant × module × hat](/blogs/software-architecture/rbac-three-axes-schema). We meet the schema that holds Maya's reality without lying about it, plus two alternatives we considered first and rejected.
