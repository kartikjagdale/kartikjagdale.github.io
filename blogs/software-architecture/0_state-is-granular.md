---
permalink: /blogs/software-architecture/state-is-granular
layout: post
title: State is Granular
---

<img src="/public/images/state-is-granular.png" width="50%"  height="50%" style="margin: 0 auto;"/>

### Design thinking Problem with State Managment in an Web Application

Most of the time we tend to live in world of Redux, we don't tend to think about State, we start thinking

Redux = State and State = Redux and this is just the way it is and get stuck in this thinking loop.

But when we get away from redux for a second, we can see we have complety different patterns in our State of an application and can be implemeted differently with methods that are more suited for those patterns.

We can see that

**𝐒𝐭𝐚𝐭𝐞 𝐢𝐬 𝐆𝐫𝐚𝐧𝐮𝐥𝐚𝐫** and we can have atleast 4 different types of State

**1. 𝐋𝐨𝐜𝐚𝐥 𝐒𝐭𝐚𝐭𝐞:** State that is managed within a single component in an application. It is not shared with other components and is used to manage component-specific data. Like Dropdown is open or closed.

**2. 𝐑𝐞𝐦𝐨𝐭𝐞 𝐒𝐭𝐚𝐭𝐞:** State that is managed on a remote server or database, such as data fetched from an API. It is accessed asynchronously and is typically shared among multiple components.

**3. 𝐀𝐬𝐲𝐧𝐜 𝐒𝐭𝐚𝐭𝐞:** State that is loaded asynchronously, can be loading or error state. Mostlt this goes hand in hand with Remote State.

**4. 𝐒𝐡𝐚𝐫𝐞𝐝 𝐒𝐭𝐚𝐭𝐞:** State that is shared among multiple components in an application. Behavior of components can be driven by the state it shares with other components.

Furthermore this states can be composed with each other to drive. the behavior of an application.

Only with these type of design thinking while using state management can be used to build truly scalable applications.

