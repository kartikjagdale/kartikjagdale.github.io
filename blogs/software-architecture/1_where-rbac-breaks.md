---
permalink: /blogs/software-architecture/where-rbac-breaks
layout: post
title: Where RBAC Breaks — A Small-Business Story
---

> Part 1 of 3: _A series on multi-tenant, multi-module, multi-hat access control._
> Next: [The three axes: tenant × module × hat](/blogs/software-architecture/rbac-three-axes-schema) (coming up)

### Meet Maya

Maya runs Sage Studios, a small chain with three locations across the city. Each location has a salon (haircuts and color), a spa (facials, massage, body treatments), and a small retail counter selling hair and skin products. About fifteen people work for her: stylists, therapists, receptionists, a cashier here and there, an admin who keeps the books.

The day Maya signed up for her shiny new business management software, she sat down with a cup of chai and started adding her team. Name. Email. Role. Send invite.

Five minutes later, she was confused.

She'd added Priya as a stylist. Then she went to put Priya on the salon's booking calendar. The software told her she needed to **add Priya as staff**. But Maya had just added her. As a stylist. Surely a stylist is staff?

She clicked into "Staff." A different page. A different button. A different form. She picked Priya from a list, then a panel appeared asking for booking hours, calendar visibility, whether Priya was "available for appointments." Maya filled it in, hit save, and went back to work.

Then she remembered Anjali, her receptionist who also helps at the retail counter on Saturdays.

She stared at the role dropdown. Anjali was a *receptionist*. But Anjali also did *retail*. The system would only let her pick one.

Maya's onboarding had a small bug, she figured. She'd email support tomorrow.

### What is "role-based access," really?

Before we go any further, let's get on the same page about what role-based access control (RBAC, if you've seen the acronym) actually is. It's simpler than the acronym makes it sound.

A **permission** is a single thing a user is allowed to do. "Edit the booking calendar." "View invoices." "Delete a customer." Each is a tiny on/off switch. In code it usually shows up as a string like `bookings:edit` or `invoices:read`.

A **role** is a bundle of permissions you give a name to. "Stylist" might bundle together `appointments:read`, `appointments:create`, `customer:view`, `services:read`. "Owner" bundles everything. "Receptionist" bundles a different set.

That's the whole concept. Roles are just labels you stick on bundles of switches so you don't have to flip every switch one-by-one when a new person joins.

Most software you've used implements RBAC something like this. Notion has Owner / Member / Guest. GitHub has Admin / Maintainer / Developer / Triage. Slack has Workspace Owner / Admin / Member. They're all variations on the same theme: pick a role, and you've picked a bundle.

It works beautifully. Until it doesn't.

### Why the simple version works fine at first

Here's the version of access control most software ships with on day one. There's a `users` table. Each user has a `role` column, or maybe a `role_id` pointing at a small `roles` table. To check if a user can do something, you look up their role and check if the permission is in their bundle.

```sql
-- The everyday version of RBAC
users (
  id, email, name, role_id
)

roles (
  id, name, permissions[]
)
```

If you're building software for a single product where every user does roughly the same kind of thing, this is fine. It's actually more than fine — it's right. Adding more complexity than you need is a worse mistake than starting too simple.

The trouble starts when "the same kind of thing" becomes plural.

### The first crack: Same person, two jobs

Anjali is the receptionist. That's her primary job — she greets customers at the front desk of the salon. But on Saturdays, when retail gets busy, she helps at the till for an hour.

In Maya's RBAC software, Anjali has one role: Receptionist. Her permission bundle includes `customer:view`, `appointments:create`, `bookings:read`. It doesn't include `retail:operate-till`.

So when Anjali tries to ring up a sale on Saturday, the software says no.

Maya now has three options. She can change Anjali's role to "Cashier" on Saturdays and back to "Receptionist" on Monday — fragile, easy to forget, breaks her system on Sunday night when nobody's there to flip it. She can create a custom role called "Receptionist + Cashier" that bundles both — works once, but now imagine Maya has thirty staff with thirty slightly-different overlap patterns. Or she can promote Anjali to "Owner" so she can do everything, and trust her not to delete things — the YOLO option, terrible for security.

None of these are good. They're all symptoms of the same diagnosis: **the system assumes Anjali has one job, but Anjali has two.**

### The second crack: the new module no one planned for

Six months in, Maya signs up for a new feature in her software: appointment scheduling for the spa. Until now her spa was running off pen-and-paper. Now there's a digital booking calendar for the spa, just like the salon's.

The software adds a new section called "Spa." It has its own staff list, its own bookings, its own pricing.

Maya's salon stylists don't operate in the spa. Most of them, anyway. But Priya i.e "Maya's senior stylist", sometimes covers the spa massage room when the regular massage therapist is out. So Priya needs to appear on the spa booking calendar too, just occasionally.

In Maya's RBAC software, Priya has one role: Senior Stylist. That role gave her access to the salon's everything but doesn't say anything about the spa.

Maya goes to add Priya to the spa. The software wants Priya to have a *spa role*. It offers her "Spa Therapist." But Priya isn't a Spa Therapist; she's a Stylist who covers the spa. There's no "Stylist who also does spa" in the dropdown. Maya improvises and picks "Spa Therapist" anyway.

Now Priya appears on both calendars. Maya's two boards overlap each other strangely; sometimes a salon client and a spa client get double-booked into Priya's slot because the system thinks of Priya as one staff member with two parallel roles, but doesn't connect their schedules.

The system has been pushed past its design.

### The third crack: The owner who's also a stylist

Maya isn't just the owner. She's also a senior stylist herself; she still cuts hair on Tuesdays and Thursdays. She wants her name on the salon booking calendar too, for those days.

But the software has her listed as "Owner", the role that gives her permission to do everything in the system. Not as a Stylist. Owners don't appear on the booking calendar by default.

Maya tries to give herself a second role. The software politely says: a person can only have one role.

You can see where this is going.

### The deeper diagnosis

We could go on. The admin who handles billing across all three locations. The cashier who covers retail at one location but not the others. The freelance massage therapist who works at all three locations, two days a week each. Each of these is a flavor of the same problem.

Here's the diagnosis: **the software was built around a single concept of "what kind of person is this user," but Maya's reality has three concepts braided together.**

There's the *business* - Maya's chain. There are the *services within the business* like salon, spa, retail. There are the *people* like each with their own combination of which services they work in and what they do there. The software collapsed all three into one column called `role_id`, and now it can't carry the weight.

This isn't a bug. It's not bad code. It's just a model that fits the simpler reality of one product, one team, one `role-per-person` and Maya's small business is a more complex reality than that.

### Why this matters before you've shipped

If you're building B2B SaaS, more of your customers will look like Maya than not. You will hit this. You'll hit it the day a customer asks if their staff member can have two roles. You'll hit it the day you add a second product surface (a "Module" in this series' language) under your platform.

You don't need to over-engineer day one. The single-role version is genuinely correct for very simple realities. But you do need to know **what shape the next version takes** before the cracks force you into a hasty migration. Because access control is one of those parts of a system where a hasty migration is genuinely painful — every page in your product reads from it, every API call enforces it, every audit trail records it.

The good news is the next version isn't very different. It's the same basic idea — roles bundle permissions — with one shift in axis. We'll see in part 2.

### A preview, in plain English

Here's what we'll build over the next two posts.

Imagine Maya's reality has three independent dimensions:

1. **The business** she's running — Sage Studios. (One business per *tenant*, in software terms.)
2. **The services within it** — salon, spa, retail. (Each is a *module*.)
3. **The people**, each with their own combination of where they work and what they do there. (Each can wear multiple *hats*.)

Traditional RBAC tries to express all three with one column. We'll express them with three columns. That's it. The schema follows. The user experience follows. The capability matrix, for the cases where roles aren't fine-grained enough — follows.

Onboarding stops being a tug-of-war between "add user" and "add staff." Maya stops getting confused on day one.

### What we're not solving

A few things this series isn't about, just so you don't read it expecting them.

We're not building **fine-grained per-row authorization** — the "this user can read THIS document but not that one" problem. Tools like Oso, OpenFGA, and SpiceDB exist for that, and they're great. We're solving the broader-shape problem of "how do roles compose across multiple apps in one platform," which is actually most B2B RBAC pain.

We're not designing **OAuth scopes or API token permissions** — that's a parallel concern. The roles we'll build are for human users inside a tenant.

We're not arguing about **whether to use RBAC vs ABAC vs ReBAC** as the underlying model. RBAC, the way most software ships it, is good enough for most B2B SaaS most of the time. We're showing how it scales, not advocating for a paradigm shift.

OK. Tea break. See you in part 2.

---

> Coming next: [Part 2: The three axes — tenant × module × hat](/blogs/software-architecture/rbac-three-axes-schema). We meet the schema that holds Maya's reality without lying about it. Plus two alternatives we considered first and rejected.
