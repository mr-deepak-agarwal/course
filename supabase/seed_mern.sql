-- ============================================================
-- Seed: "MERN Stack Foundations" — the first course
-- Run after schema.sql. Swap video_url placeholders for your
-- own unlisted YouTube/Vimeo embed links before publishing.
-- ============================================================

with new_course as (
  insert into courses (slug, title, description, order_index)
  values (
    'mern-stack-foundations',
    'MERN Stack Foundations',
    'Build and ship a full-stack app with MongoDB, Express, React, and Node — from schema to deployment.',
    1
  )
  returning id
),
mod_1 as (
  insert into modules (course_id, title, order_index)
  select id, 'MongoDB Basics', 1 from new_course returning id, course_id
),
mod_2 as (
  insert into modules (course_id, title, order_index)
  select id, 'Express & REST APIs', 2 from new_course returning id, course_id
),
mod_3 as (
  insert into modules (course_id, title, order_index)
  select id, 'React Fundamentals', 3 from new_course returning id, course_id
),
mod_4 as (
  insert into modules (course_id, title, order_index)
  select id, 'Node.js & Deployment', 4 from new_course returning id, course_id
)
insert into lessons (module_id, title, content, video_url, order_index)
select id, title, content, video_url, order_index from (
  select (select id from mod_1) as id,
    'What is MongoDB?' as title,
    'MongoDB is a document-oriented NoSQL database. Instead of rows and columns, data lives as JSON-like documents inside collections. This makes it a natural fit for JavaScript-based stacks since your app code and your stored data share the same shape.' as content,
    'https://www.youtube.com/embed/REPLACE_ME_MONGO_INTRO' as video_url,
    1 as order_index
  union all
  select (select id from mod_1), 'Collections, Documents & CRUD',
    'Learn to create, read, update, and delete documents using the MongoDB shell and Node driver. Covers _id, indexes, and basic query operators like $gt, $in, and $set.',
    'https://www.youtube.com/embed/REPLACE_ME_MONGO_CRUD', 2
  union all
  select (select id from mod_2), 'Building a REST API with Express',
    'Set up an Express server, define routes for a resource, and structure your project with routers, controllers, and middleware.',
    'https://www.youtube.com/embed/REPLACE_ME_EXPRESS_REST', 1
  union all
  select (select id from mod_2), 'Connecting Express to MongoDB with Mongoose',
    'Define schemas and models with Mongoose, validate incoming data, and wire your API routes to real database operations.',
    'https://www.youtube.com/embed/REPLACE_ME_MONGOOSE', 2
  union all
  select (select id from mod_3), 'Components, Props & State',
    'The building blocks of a React app: function components, passing data down through props, and managing local state with useState.',
    'https://www.youtube.com/embed/REPLACE_ME_REACT_BASICS', 1
  union all
  select (select id from mod_3), 'Fetching Data & useEffect',
    'Call your Express API from React using fetch, manage loading and error states, and understand the useEffect dependency array.',
    'https://www.youtube.com/embed/REPLACE_ME_REACT_FETCH', 2
  union all
  select (select id from mod_4), 'Node.js Under the Hood',
    'The event loop, async/await, and how Node handles concurrency without multithreading. Why this matters for API performance.',
    'https://www.youtube.com/embed/REPLACE_ME_NODE_EVENTLOOP', 1
  union all
  select (select id from mod_4), 'Deploying Your MERN App',
    'Ship the React build and Express API together: environment variables, CORS, and a simple deployment to a host like Render or Railway.',
    'https://www.youtube.com/embed/REPLACE_ME_DEPLOY', 2
) as lesson_data;

-- ---------- Quiz ----------
with course as (select id from courses where slug = 'mern-stack-foundations'),
new_quiz as (
  insert into quizzes (course_id, title, passing_score)
  select id, 'MERN Stack Foundations — Final Test', 70 from course
  returning id
)
insert into questions (quiz_id, question, options, correct_index, order_index)
select id, question, options::jsonb, correct_index, order_index from (
  select (select id from new_quiz) as id,
    'MongoDB stores data primarily as:' as question,
    '["Rows and columns","JSON-like documents","Key-value pairs only","XML files"]' as options,
    1 as correct_index, 1 as order_index
  union all
  select (select id from new_quiz),
    'In Express, which function signature represents middleware?',
    '["(req, res, next)","(req, res)","(err)","(app, port)"]',
    0, 2
  union all
  select (select id from new_quiz),
    'Which React hook lets you run code after a component renders?',
    '["useState","useRef","useEffect","useMemo"]',
    2, 3
  union all
  select (select id from new_quiz),
    'Mongoose is best described as:',
    '["A CSS framework","An ODM for MongoDB and Node","A React state manager","A deployment platform"]',
    1, 4
  union all
  select (select id from new_quiz),
    'What lets a React app call an Express API on a different origin during development?',
    '["CORS configuration","MongoDB indexes","JWT signing","Tailwind config"]',
    0, 5
) as question_data;
