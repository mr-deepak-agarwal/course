-- ============================================================
-- Job-Ready Portal — COMPLETE SETUP in one file
-- For a FRESH Supabase project. Paste into the SQL editor and Run once.
-- Order: schema -> MERN seed -> Python for AI seed -> patch 01 -> 02 -> 03
-- Afterwards, sign up on your site and run the 'make admin' snippet at the very bottom.
-- ============================================================

-- ################################################################
-- PART: schema.sql
-- ################################################################
-- ============================================================
-- Job-Ready Portal — schema
-- Run this in the Supabase SQL editor (or via supabase db push)
-- ============================================================

create extension if not exists "pgcrypto";

-- ---------- profiles (one row per auth.users, one login per student) ----------
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  stream text not null check (stream in ('BCA','BTech','MCA','MTech','Other')),
  college text,
  created_at timestamptz default now()
);

-- ---------- courses (generic — any stream, any subject) ----------
create table if not exists courses (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  title text not null,
  description text,
  is_published boolean not null default true,
  order_index int not null default 0,
  created_at timestamptz default now()
);

create table if not exists modules (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references courses(id) on delete cascade,
  title text not null,
  order_index int not null default 0
);

create table if not exists lessons (
  id uuid primary key default gen_random_uuid(),
  module_id uuid not null references modules(id) on delete cascade,
  title text not null,
  content text,          -- markdown body
  video_url text,        -- youtube/vimeo embed URL
  order_index int not null default 0
);

-- ---------- quiz ----------
create table if not exists quizzes (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references courses(id) on delete cascade,
  title text not null default 'Final Test',
  passing_score int not null default 70 -- percent
);

create table if not exists questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references quizzes(id) on delete cascade,
  question text not null,
  options jsonb not null,      -- e.g. ["A","B","C","D"]
  correct_index int not null,  -- 0-based index into options
  order_index int not null default 0
);

-- ---------- student activity ----------
create table if not exists enrollments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references profiles(id) on delete cascade,
  course_id uuid not null references courses(id) on delete cascade,
  enrolled_at timestamptz default now(),
  unique (student_id, course_id)
);

create table if not exists quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references profiles(id) on delete cascade,
  quiz_id uuid not null references quizzes(id) on delete cascade,
  score int not null,        -- percent
  passed boolean not null,
  submitted_at timestamptz default now()
);

create table if not exists certificates (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references profiles(id) on delete cascade,
  course_id uuid not null references courses(id) on delete cascade,
  certificate_code text unique not null default encode(gen_random_bytes(6), 'hex'),
  issued_at timestamptz default now(),
  unique (student_id, course_id)
);

-- ============================================================
-- Row Level Security
-- ============================================================
alter table profiles enable row level security;
alter table courses enable row level security;
alter table modules enable row level security;
alter table lessons enable row level security;
alter table quizzes enable row level security;
alter table questions enable row level security;
alter table enrollments enable row level security;
alter table quiz_attempts enable row level security;
alter table certificates enable row level security;

-- profiles: a student can read/update only their own profile
create policy "profile self read" on profiles for select using (auth.uid() = id);
create policy "profile self insert" on profiles for insert with check (auth.uid() = id);
create policy "profile self update" on profiles for update using (auth.uid() = id);

-- course content: any signed-in student can read published content
create policy "courses read" on courses for select using (is_published = true);
create policy "modules read" on modules for select using (
  exists (select 1 from courses c where c.id = modules.course_id and c.is_published)
);
create policy "lessons read" on lessons for select using (
  exists (
    select 1 from modules m join courses c on c.id = m.course_id
    where m.id = lessons.module_id and c.is_published
  )
);
create policy "quizzes read" on quizzes for select using (
  exists (select 1 from courses c where c.id = quizzes.course_id and c.is_published)
);
create policy "questions read" on questions for select using (
  exists (
    select 1 from quizzes q join courses c on c.id = q.course_id
    where q.id = questions.quiz_id and c.is_published
  )
);

-- enrollments: student manages their own
create policy "enrollments self all" on enrollments for all
  using (auth.uid() = student_id) with check (auth.uid() = student_id);

-- quiz attempts: student manages their own
create policy "attempts self all" on quiz_attempts for all
  using (auth.uid() = student_id) with check (auth.uid() = student_id);

-- certificates: student can read + insert their own
create policy "certificates self read" on certificates for select using (auth.uid() = student_id);
create policy "certificates self insert" on certificates for insert with check (auth.uid() = student_id);

-- ============================================================
-- Public verification view — only non-sensitive fields, no auth required
-- ============================================================
create or replace view certificate_public as
select
  cert.certificate_code,
  p.full_name as student_name,
  p.stream,
  c.title as course_title,
  cert.issued_at
from certificates cert
join profiles p on p.id = cert.student_id
join courses c on c.id = cert.course_id;

grant select on certificate_public to anon, authenticated;

-- ============================================================
-- Auto-create a profile row whenever a new auth user signs up.
-- Runs as SECURITY DEFINER so it bypasses RLS — this replaces
-- any client-side insert into `profiles`, which would otherwise
-- fail until the user's session is fully authenticated (e.g. if
-- email confirmation is required).
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, stream, college)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce(new.raw_user_meta_data->>'stream', 'Other'),
    new.raw_user_meta_data->>'college'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ################################################################
-- PART: seed_mern.sql
-- ################################################################
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
  select id, 'MERN Stack Foundations — Final Test', 40 from course
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

-- ################################################################
-- PART: seed_python_ai.sql
-- ################################################################
-- ============================================================
-- Seed: "Python for AI — 21 Days"
-- Run AFTER schema.sql and patch_01 / patch_02.
-- 3 modules (weeks) x 7 lessons (days) = 21 lessons, 15-question test (pass mark 40%).
-- video_url is left NULL: set each lesson's embed link later with
--   update lessons set video_url = 'https://www.youtube.com/embed/ID'
--   where title like 'Day 1:%';
-- Not re-runnable: it stops if the course already exists (so it can never
-- wipe a course that students have progress or certificates on).
-- ============================================================

do $$
begin
  if exists (select 1 from courses where slug = 'python-for-ai-21-days') then
    raise exception 'Course python-for-ai-21-days already exists - delete it first if you really want to re-seed.';
  end if;
end $$;

with new_course as (
  insert into courses (slug, title, description, order_index)
  values (
    'python-for-ai-21-days',
    'Python for AI — 21 Days',
    'Go from zero Python to building a working machine-learning and LLM-powered app in 21 days: one focused lesson a day.',
    2
  )
  returning id
),
mods as (
  insert into modules (course_id, title, order_index)
  select nc.id, v.title, v.idx
  from new_course nc,
  (values
    ('Week 1 — Python Foundations', 1),
    ('Week 2 — Data Skills: NumPy, Pandas & Plots', 2),
    ('Week 3 — Machine Learning & LLM Apps', 3)
  ) as v(title, idx)
  returning id, order_index
)
insert into lessons (module_id, title, content, video_url, order_index)
select m.id, l.title, l.content, null, l.day
from mods m
join (values

-- ======================= WEEK 1 =======================
(1, 1, 'Day 1: Setup & Your First Python Program', $md$
Python is the main language of AI because of its readable syntax and its huge ecosystem (NumPy, Pandas, scikit-learn, PyTorch). Today you set up and run your first program.

**Set up**
1. Install Python 3.11+ from python.org (tick "Add to PATH" on Windows).
2. Check it: `python --version`
3. Create an isolated environment for the course:

```bash
python -m venv ai-env
source ai-env/bin/activate      # Windows: ai-env\Scripts\activate
pip install --upgrade pip
```

No installs allowed on your laptop? Use **Google Colab** (colab.research.google.com): free, runs in the browser.

**Your first program** — save as `hello.py`:

```python
name = "Asha"
print("Hello,", name)
print("Today I start learning Python for AI!")
```

Run it with `python hello.py`.

**Practice:** change the name, add a line that prints your college and stream.
$md$),

(1, 2, 'Day 2: Variables, Data Types & Operators', $md$
A **variable** is a name that points to a value. Python figures out the type itself.

```python
age = 21              # int
height = 1.72         # float
name = "Ravi"         # str
is_student = True     # bool
print(type(age), type(height))
```

**Operators**

```python
10 + 3    # 13
10 / 3    # 3.333...  (true division)
10 // 3   # 3         (floor division)
10 % 3    # 1         (remainder)
2 ** 10   # 1024      (power)
age >= 18 and is_student   # True
```

**Type conversion** matters when you read input, because `input()` always returns text:

```python
marks = int(input("Enter marks: "))
print(marks * 2)
```

**Practice:** write a program that takes the price and quantity of an item and prints the total with 18% GST.
$md$),

(1, 3, 'Day 3: Strings & Formatting', $md$
Text is everywhere in AI (chatbots, search, sentiment), so get comfortable with strings.

```python
s = "Machine Learning"
s.lower()            # 'machine learning'
s.upper()            # 'MACHINE LEARNING'
s.split(" ")         # ['Machine', 'Learning']
s[0]                 # 'M'
s[-8:]               # 'Learning'  (slicing)
len(s)               # 16
"Learn" in s         # True
s.replace("Machine", "Deep")
```

**f-strings** are the cleanest way to build text:

```python
name, score = "Ravi", 87.456
print(f"{name} scored {score:.1f}%")   # Ravi scored 87.5%
```

Strings are **immutable**: methods return a new string instead of changing the old one.

**Practice:** take a sentence from the user, print the number of words and the sentence in title case.
$md$),

(1, 4, 'Day 4: Control Flow — if, for and while', $md$
Programs make decisions and repeat work.

```python
marks = 72
if marks >= 90:
    grade = "A"
elif marks >= 60:
    grade = "B"
else:
    grade = "C"
print(grade)
```

**Loops**

```python
for i in range(5):          # 0,1,2,3,4
    print(i)

for ch in "AI":
    print(ch)

count = 0
while count < 3:
    print("tick")
    count += 1
```

`break` leaves a loop early, `continue` skips to the next round. Indentation (4 spaces) defines the block, so it is part of the syntax.

**Practice:** print all numbers from 1 to 50 that are divisible by 3 or 5 (FizzBuzz variation).
$md$),

(1, 5, 'Day 5: Lists, Tuples, Sets & Dictionaries', $md$
These four containers hold almost all the data you will touch.

```python
scores = [80, 92, 67]          # list: ordered, changeable
scores.append(75)
scores.sort()

point = (3, 4)                 # tuple: ordered, fixed

tags = {"ai", "ml", "ai"}      # set: unique values -> {'ai', 'ml'}

student = {"name": "Asha", "marks": 91}   # dict: key -> value
student["city"] = "Jaipur"
print(student.get("age", "unknown"))
for key, value in student.items():
    print(key, value)
```

Rule of thumb: need order and changes → **list**; need unique items or fast membership checks → **set**; need lookup by name → **dict**. JSON, which every API speaks, maps directly onto dicts and lists.

**Practice:** given a list of words, build a dict that counts how often each word appears.
$md$),

(1, 6, 'Day 6: Functions & List Comprehensions', $md$
A **function** packages reusable logic.

```python
def average(numbers, round_to=2):
    """Return the mean of a list of numbers."""
    if not numbers:
        return 0
    return round(sum(numbers) / len(numbers), round_to)

print(average([80, 92, 67]))
```

- Parameters can have defaults (`round_to=2`).
- A function without `return` gives back `None`.
- Variables created inside a function stay inside it (local scope).

**Comprehensions** build lists in one line:

```python
squares = [x ** 2 for x in range(1, 6)]            # [1, 4, 9, 16, 25]
evens = [x for x in range(20) if x % 2 == 0]
lengths = {w: len(w) for w in ["ai", "python"]}    # dict comprehension
```

**Practice:** write `is_prime(n)` and use a comprehension to list the primes under 100.
$md$),

(1, 7, 'Day 7: Files, Errors, Modules & Mini Project', $md$
**Reading and writing files** — always use `with`, which closes the file for you:

```python
with open("notes.txt", "w") as f:
    f.write("python is fun\nai is fun\n")

with open("notes.txt") as f:
    text = f.read()
```

**Handling errors**

```python
try:
    n = int(input("Number: "))
    print(10 / n)
except ValueError:
    print("That is not a number")
except ZeroDivisionError:
    print("Cannot divide by zero")
```

**Modules** are other people's code: `import random`, `import json`, `from collections import Counter`.

**Mini project — Word Counter:** read `notes.txt`, use `Counter(text.split())`, print the 3 most common words with `.most_common(3)`, and save the result to `result.json` using `json.dump`.

Week 1 done. You can now read and write real Python.
$md$),

-- ======================= WEEK 2 =======================
(2, 8, 'Day 8: Classes & Objects (OOP Basics)', $md$
Libraries like scikit-learn and PyTorch are built from **classes**, so you need to read them fluently.

```python
class Student:
    def __init__(self, name, marks):
        self.name = name
        self.marks = marks

    def grade(self):
        return "Pass" if self.marks >= 40 else "Fail"

    def __repr__(self):
        return f"Student({self.name!r}, {self.marks})"

s = Student("Asha", 91)
print(s.grade(), s)
```

- `__init__` runs when you create an object.
- `self` is the object itself.
- **Inheritance** lets one class extend another: `class Topper(Student): ...`

You will soon see the same pattern in ML: `model = LinearRegression()` creates an object, `model.fit(X, y)` and `model.predict(X)` are its methods.

**Practice:** build a `BankAccount` class with `deposit`, `withdraw` (block overdrafts) and `balance`.
$md$),

(2, 9, 'Day 9: NumPy — Fast Arrays', $md$
NumPy is the foundation under almost every AI library. Its arrays are far faster than Python lists because the math runs in compiled code.

```bash
pip install numpy
```

```python
import numpy as np

a = np.array([1, 2, 3, 4])
b = np.array([[1, 2], [3, 4], [5, 6]])

print(a.shape, b.shape)      # (4,) (3, 2)
print(a * 2)                 # [2 4 6 8]  -> no loop needed
print(np.zeros((2, 3)))
print(np.arange(0, 10, 2))   # [0 2 4 6 8]
print(np.linspace(0, 1, 5))
```

**Indexing and slicing**

```python
b[0, 1]       # 2
b[:, 0]       # first column -> [1 3 5]
a[a > 2]      # boolean mask -> [3 4]
```

**Practice:** create 1,000,000 random numbers with `np.random.rand` and compare the time of `sum()` vs `np.sum()`.
$md$),

(2, 10, 'Day 10: NumPy Math, Broadcasting & Statistics', $md$
Machine learning is mostly linear algebra on arrays.

```python
import numpy as np

X = np.array([[1, 2], [3, 4], [5, 6]])
w = np.array([0.5, -1])

print(X @ w)                 # matrix-vector product
print(X.T)                   # transpose
print(X.mean(), X.std())
print(X.mean(axis=0))        # mean of each column
print(X.reshape(2, 3))
```

**Broadcasting** lets arrays of different shapes combine:

```python
X - X.mean(axis=0)           # subtract each column's mean: "centering" data
(X - X.mean(axis=0)) / X.std(axis=0)   # standardisation
```

Standardising features like this is a standard ML preprocessing step.

**Practice:** generate 100 random exam marks with `np.random.randint(30, 100, 100)` and print the mean, median, max and how many are above the mean.
$md$),

(2, 11, 'Day 11: Pandas — DataFrames', $md$
Pandas is Excel plus SQL inside Python. Its main object is the **DataFrame**, a table.

```bash
pip install pandas
```

```python
import pandas as pd

df = pd.DataFrame({
    "name": ["Asha", "Ravi", "Meera", "Karan"],
    "stream": ["BCA", "BTech", "BCA", "MCA"],
    "marks": [91, 67, 78, 85],
})

print(df.head())
print(df.info())
print(df.describe())

df["marks"]                       # a column (Series)
df[df["marks"] > 80]              # filter rows
df.sort_values("marks", ascending=False)
df["passed"] = df["marks"] >= 40  # new column
```

**Load real data:** `pd.read_csv("students.csv")`, and save with `df.to_csv("out.csv", index=False)`.

**Practice:** download any CSV from Kaggle (for example the Titanic data), load it and print `shape`, `head()` and `describe()`.
$md$),

(2, 12, 'Day 12: Cleaning Data', $md$
Real data is messy, and good models need clean data. Expect to spend most of your time here.

```python
df.isna().sum()                       # missing values per column
df["age"] = df["age"].fillna(df["age"].median())
df = df.dropna(subset=["fare"])       # drop rows missing a key field
df = df.drop_duplicates()
df["city"] = df["city"].str.strip().str.title()
df["date"] = pd.to_datetime(df["date"])
df["marks"] = df["marks"].astype(int)
```

**Encoding categories as numbers** (models need numbers):

```python
df = pd.get_dummies(df, columns=["stream"])      # one-hot encoding
```

**Outliers:** check with `df["marks"].describe()` and a box plot (tomorrow). Decide whether a strange value is an error or a real signal before removing it.

**Practice:** on your CSV from Day 11, list every column with missing values and choose a fill strategy for each, writing one line of reasoning.
$md$),

(2, 13, 'Day 13: groupby & Visualisation with Matplotlib', $md$
**Summarise** with `groupby`:

```python
df.groupby("stream")["marks"].mean()
df.groupby("stream").agg(avg=("marks", "mean"), n=("marks", "count"))
df["stream"].value_counts()
```

**Plot** with Matplotlib:

```bash
pip install matplotlib
```

```python
import matplotlib.pyplot as plt

df["marks"].plot(kind="hist", bins=10, title="Marks distribution")
plt.xlabel("Marks")
plt.show()

df.groupby("stream")["marks"].mean().plot(kind="bar")
plt.ylabel("Average marks")
plt.tight_layout()
plt.savefig("avg_marks.png", dpi=150)
```

Pick the chart for the question: **histogram** for one variable's spread, **bar** for comparing categories, **scatter** for the relationship between two numbers, **line** for change over time. Always label your axes.

**Practice:** make three charts from your dataset, each answering one question.
$md$),

(2, 14, 'Day 14: Mini Project — Exploratory Data Analysis', $md$
Combine the whole week into one notebook. Use a dataset you find interesting (Titanic, house prices, IPL, spotify tracks).

**Checklist**
1. **Question:** write 3 questions the data might answer.
2. **Load & inspect:** `shape`, `info()`, `describe()`, `head()`.
3. **Clean:** missing values, duplicates, wrong types.
4. **Explore:** `groupby` summaries, correlations with `df.corr(numeric_only=True)`.
5. **Visualise:** at least 4 labelled charts.
6. **Conclude:** 5 bullet points, each backed by a number or chart.

```python
import pandas as pd, matplotlib.pyplot as plt
df = pd.read_csv("titanic.csv")
print(df.groupby("Sex")["Survived"].mean())
df.groupby("Pclass")["Survived"].mean().plot(kind="bar")
plt.show()
```

**Deliverable:** push the notebook to GitHub with a README summarising your findings. Recruiters read this.

Week 2 done. You can now handle data.
$md$),

-- ======================= WEEK 3 =======================
(3, 15, 'Day 15: What Is Machine Learning?', $md$
Instead of writing rules by hand, we show a model many **examples** and let it find the pattern.

- **Supervised learning:** examples come with answers (labels). *Regression* predicts a number (house price); *classification* predicts a category (spam / not spam).
- **Unsupervised learning:** no labels; find structure, for example grouping customers (clustering).

**The standard workflow**
1. Collect and clean data
2. Choose features **X** (inputs) and target **y** (answer)
3. **Split** into training and test sets
4. **Fit** a model on the training set
5. **Evaluate** on the test set it has never seen

```python
from sklearn.model_selection import train_test_split

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)
```

Why split? A model can memorise its training data. Only performance on unseen data tells you if it learned something real.

```bash
pip install scikit-learn
```
$md$),

(3, 16, 'Day 16: Your First Model — Regression', $md$
Predict a number from other numbers using **linear regression**.

```python
import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error, r2_score

# hours studied -> marks (toy data)
rng = np.random.default_rng(0)
hours = rng.uniform(1, 10, 100).reshape(-1, 1)
marks = 35 + 6 * hours.ravel() + rng.normal(0, 5, 100)

X_train, X_test, y_train, y_test = train_test_split(
    hours, marks, test_size=0.2, random_state=42
)

model = LinearRegression()
model.fit(X_train, y_train)

pred = model.predict(X_test)
print("Slope:", model.coef_[0], "Intercept:", model.intercept_)
print("MAE:", mean_absolute_error(y_test, pred))
print("R2:", r2_score(y_test, pred))
print(model.predict([[7.5]]))
```

The model should find a slope near 6 and an intercept near 35, the numbers used to create the data. **MAE** is the average error in marks; **R²** says how much of the variation is explained (1.0 is perfect).

**Practice:** repeat on a real dataset such as house prices.
$md$),

(3, 17, 'Day 17: Classification & Evaluation Metrics', $md$
Predict a **category**. Example: will a Titanic passenger survive?

```python
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix

clf = RandomForestClassifier(n_estimators=200, random_state=42)
clf.fit(X_train, y_train)
pred = clf.predict(X_test)

print(accuracy_score(y_test, pred))
print(confusion_matrix(y_test, pred))
print(classification_report(y_test, pred))
```

**Accuracy can lie.** If 95% of emails are not spam, a model that always says "not spam" is 95% accurate and useless. Use:
- **Precision:** of those predicted positive, how many really were?
- **Recall:** of all real positives, how many did we catch?
- **F1:** balance of the two.

Pick the metric by the cost of a mistake: missing a cancer case (recall) is worse than a false alarm.

**Practice:** train `LogisticRegression` and `RandomForestClassifier` on the same data and compare the reports.
$md$),

(3, 18, 'Day 18: Overfitting, Cross-Validation & Pipelines', $md$
**Overfitting:** the model scores great on training data but poorly on new data, because it memorised noise. **Underfitting:** it is too simple to learn the pattern at all.

Spot it by comparing scores:

```python
print("train:", clf.score(X_train, y_train))
print("test: ", clf.score(X_test, y_test))
```

A big gap means overfitting. Fixes: more data, simpler model (`max_depth=5`), regularisation, fewer features.

**Cross-validation** gives a more reliable estimate than one split:

```python
from sklearn.model_selection import cross_val_score
scores = cross_val_score(clf, X, y, cv=5)
print(scores.mean(), scores.std())
```

**Pipelines** bundle preprocessing and the model so you never leak test data into training:

```python
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression

pipe = make_pipeline(StandardScaler(), LogisticRegression(max_iter=1000))
pipe.fit(X_train, y_train)
```

Save a trained model with `joblib.dump(pipe, "model.joblib")` and load it later with `joblib.load`.
$md$),

(3, 19, 'Day 19: Calling APIs & Using LLMs from Python', $md$
Large language models are used through **APIs**: you send a request over HTTP and receive JSON.

```bash
pip install requests python-dotenv
```

```python
import requests

r = requests.get("https://api.github.com/users/octocat", timeout=10)
r.raise_for_status()
data = r.json()
print(data["name"], data["public_repos"])
```

**Never hard-code secrets.** Keep keys in a `.env` file and add `.env` to `.gitignore`:

```python
import os
from dotenv import load_dotenv
load_dotenv()
API_KEY = os.environ["LLM_API_KEY"]
```

**Calling an LLM** (the same idea with any provider's SDK):

```python
# pip install anthropic   (or openai, google-genai ...)
import anthropic
client = anthropic.Anthropic()          # reads ANTHROPIC_API_KEY from the environment
msg = client.messages.create(
    model="claude-sonnet-4-5",          # use a current model name from the docs
    max_tokens=300,
    messages=[{"role": "user", "content": "Explain overfitting in 2 lines."}],
)
print(msg.content[0].text)
```

Check your provider's docs for current model names and pricing, and set a spending limit before experimenting.
$md$),

(3, 20, 'Day 20: Build a Small LLM-Powered App', $md$
Today you wrap a model in a useful function. Project idea: a **resume bullet improver** or **study-notes summariser**.

**Prompting basics**
- Give a clear role and task.
- Give the format you want (JSON, bullet list).
- Give an example when the task is subtle.
- Keep user input separate from instructions.

```python
import anthropic

client = anthropic.Anthropic()

SYSTEM = (
    "You are a career coach for fresh graduates. Rewrite the resume bullet to be "
    "specific, action-led and under 20 words. Return only the rewritten bullet."
)

def improve(bullet: str) -> str:
    msg = client.messages.create(
        model="claude-sonnet-4-5",
        max_tokens=100,
        system=SYSTEM,
        messages=[{"role": "user", "content": bullet}],
    )
    return msg.content[0].text.strip()

print(improve("worked on a website for college fest"))
```

**Make it an app** with Streamlit:

```python
# pip install streamlit      run: streamlit run app.py
import streamlit as st
text = st.text_area("Paste a resume bullet")
if st.button("Improve") and text:
    st.write(improve(text))
```

Handle failure: wrap the call in `try/except`, and never let a user's input reveal your key.
$md$),

(3, 21, 'Day 21: Capstone — Ship Your AI Project', $md$
Finish with one portfolio-ready project. Choose one:

1. **Prediction app:** train a model on a real dataset (house price, loan approval, student performance) and serve it with Streamlit.
2. **LLM app:** the Day 20 tool, extended with a second feature.
3. **Data story:** your Day 14 EDA, upgraded with a model and a clear conclusion.

**Definition of done**
- Code in a public GitHub repo with a clear `README.md`: problem, data source, how to run it, results and screenshots.
- `requirements.txt` (`pip freeze > requirements.txt`), so anyone can reproduce it.
- No secrets committed.
- An honest "limitations" section: what the model gets wrong.

**Deploy:** Streamlit Community Cloud, Hugging Face Spaces or Render all have free tiers.

**Where next:** deep learning with PyTorch, NLP with Hugging Face, FastAPI to serve models, SQL for data work.

Complete this lesson, then take the final test. Good luck, and well done for showing up for 21 days.
$md$)

) as l(week, day, title, content) on l.week = m.order_index;

-- ---------- Final test ----------
with course as (select id from courses where slug = 'python-for-ai-21-days'),
new_quiz as (
  insert into quizzes (course_id, title, passing_score)
  select id, 'Python for AI — Final Test', 40 from course
  returning id
)
insert into questions (quiz_id, question, options, correct_index, order_index)
select id, question, options::jsonb, correct_index, order_index from (
  select (select id from new_quiz) as id,
    'What does `10 // 3` evaluate to in Python?' as question,
    '["3.33","3","1","4"]' as options, 1 as correct_index, 1 as order_index
  union all select (select id from new_quiz),
    'Which data structure stores unique values only?',
    '["list","tuple","set","dict"]', 2, 2
  union all select (select id from new_quiz),
    'What does `input()` always return?',
    '["An int","A float","A string","A bool"]', 2, 3
  union all select (select id from new_quiz),
    'What does `[x ** 2 for x in range(1, 4)]` produce?',
    '["[1, 4, 9]","[1, 2, 3]","[1, 4, 9, 16]","[2, 4, 6]"]', 0, 4
  union all select (select id from new_quiz),
    'Why use `with open(...) as f`?',
    '["It makes reading faster","It closes the file automatically","It encrypts the file","It creates a backup"]', 1, 5
  union all select (select id from new_quiz),
    'In a class, what does `self` refer to?',
    '["The class name","The module","The current object","The parent class"]', 2, 6
  union all select (select id from new_quiz),
    'Why is NumPy faster than plain Python lists for numeric work?',
    '["It uses compiled, vectorised operations","It stores only integers","It runs on the GPU by default","It is written in pure Python with no loops"]', 0, 7
  union all select (select id from new_quiz),
    'Which Pandas call shows the number of missing values per column?',
    '["df.isna().sum()","df.missing()","df.count_null()","df.describe(na=True)"]', 0, 8
  union all select (select id from new_quiz),
    'Which chart best shows the distribution of a single numeric variable?',
    '["Pie chart","Histogram","Line chart","Scatter plot of two variables"]', 1, 9
  union all select (select id from new_quiz),
    'Predicting a house price is an example of:',
    '["Classification","Clustering","Regression","Reinforcement learning"]', 2, 10
  union all select (select id from new_quiz),
    'Why do we split data into training and test sets?',
    '["To make training faster","To check performance on data the model has not seen","To remove outliers","To balance the classes"]', 1, 11
  union all select (select id from new_quiz),
    'A model scores 99% on training data but 60% on test data. This is most likely:',
    '["Underfitting","Overfitting","Perfect generalisation","Data leakage fixed"]', 1, 12
  union all select (select id from new_quiz),
    '95% of emails are not spam. A model that always predicts "not spam" gets 95% accuracy. What does this show?',
    '["The model is excellent","Accuracy can be misleading on imbalanced data","Recall is always 100%","Precision is meaningless"]', 1, 13
  union all select (select id from new_quiz),
    'Where should an API key be stored?',
    '["Hard-coded in the script","In a public GitHub README","In an environment variable or .env file kept out of Git","In the page title"]', 2, 14
  union all select (select id from new_quiz),
    'What is the main benefit of an sklearn Pipeline?',
    '["It makes the model larger","It bundles preprocessing with the model and avoids leaking test data","It removes the need to train","It plots results automatically"]', 1, 15
) as question_data;

-- ################################################################
-- PART: patch_01_secure_quiz.sql
-- ################################################################
-- ============================================================
-- Patch 01 — close the quiz/certificate holes before demoing
-- Run AFTER schema.sql and seed_mern.sql, in the Supabase SQL editor.
-- Safe to re-run.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Stop shipping the answer key to the browser.
--    `questions` holds correct_index, so the client must never
--    read that table directly. It reads this view instead.
-- ------------------------------------------------------------
drop policy if exists "questions read" on questions;
revoke select on questions from anon, authenticated;

create or replace view questions_public as
select qs.id, qs.quiz_id, qs.question, qs.options, qs.order_index
from questions qs
join quizzes q on q.id = qs.quiz_id
join courses c on c.id = q.course_id
where c.is_published;

grant select on questions_public to authenticated;

-- ------------------------------------------------------------
-- 2. Stop letting the browser mint its own certificate.
-- ------------------------------------------------------------
drop policy if exists "certificates self insert" on certificates;

-- attempts become read-only to the student; only the function below writes them
drop policy if exists "attempts self all" on quiz_attempts;
create policy "attempts self read" on quiz_attempts
  for select using (auth.uid() = student_id);

-- ------------------------------------------------------------
-- 3. Score the test server-side and issue the certificate here.
--    p_answers is { "<question_id>": <selected_option_index>, ... }
-- ------------------------------------------------------------
create or replace function public.submit_quiz(p_quiz_id uuid, p_answers jsonb)
returns table (score int, passed boolean, certificate_code text)
language plpgsql
security definer set search_path = public
as $$
declare
  v_user     uuid := auth.uid();
  v_course   uuid;
  v_pass     int;
  v_total    int;
  v_correct  int;
  v_score    int;
  v_passed   boolean;
  v_code     text;
begin
  if v_user is null then
    raise exception 'Not authenticated';
  end if;

  select q.course_id, q.passing_score
    into v_course, v_pass
  from quizzes q
  where q.id = p_quiz_id;

  if v_course is null then
    raise exception 'Quiz not found';
  end if;

  select count(*) into v_total
  from questions
  where quiz_id = p_quiz_id;

  select count(*) into v_correct
  from questions qs
  where qs.quiz_id = p_quiz_id
    and (p_answers ->> qs.id::text)::int = qs.correct_index;

  v_score := case when v_total = 0 then 0
                  else round((v_correct::numeric / v_total) * 100) end;
  v_passed := v_score >= v_pass;

  insert into quiz_attempts (student_id, quiz_id, score, passed)
  values (v_user, p_quiz_id, v_score, v_passed);

  if v_passed then
    insert into certificates (student_id, course_id)
    values (v_user, v_course)
    on conflict (student_id, course_id) do nothing;

    select c.certificate_code into v_code
    from certificates c
    where c.student_id = v_user and c.course_id = v_course;
  end if;

  return query select v_score, v_passed, v_code;
end;
$$;

revoke all on function public.submit_quiz(uuid, jsonb) from public, anon;
grant execute on function public.submit_quiz(uuid, jsonb) to authenticated;

-- ------------------------------------------------------------
-- 4. Verification: look up ONE code, never list everything.
--    The old open grant on certificate_public let anyone with the
--    anon key dump every certificate holder's name.
-- ------------------------------------------------------------
revoke select on certificate_public from anon, authenticated;

create or replace function public.verify_certificate(p_code text)
returns table (
  certificate_code text,
  student_name     text,
  stream           text,
  course_title     text,
  issued_at        timestamptz
)
language sql
security definer set search_path = public
stable
as $$
  select cert.certificate_code,
         p.full_name,
         p.stream,
         c.title,
         cert.issued_at
  from certificates cert
  join profiles p on p.id = cert.student_id
  join courses  c on c.id = cert.course_id
  where cert.certificate_code = p_code;
$$;

grant execute on function public.verify_certificate(text) to anon, authenticated;

-- ################################################################
-- PART: patch_02_lesson_progress.sql
-- ################################################################
-- ============================================================
-- Patch 02 — lesson progress tracking, gating the test behind it
-- Run AFTER patch_01_secure_quiz.sql. Safe to re-run.
-- ============================================================

-- ------------------------------------------------------------
-- 1. One row per lesson a student has marked as read/watched.
-- ------------------------------------------------------------
create table if not exists lesson_progress (
  student_id   uuid not null references profiles(id) on delete cascade,
  lesson_id    uuid not null references lessons(id) on delete cascade,
  completed_at timestamptz not null default now(),
  primary key (student_id, lesson_id)
);

alter table lesson_progress enable row level security;

drop policy if exists "lesson_progress self all" on lesson_progress;
create policy "lesson_progress self all" on lesson_progress
  for all
  using (auth.uid() = student_id)
  with check (auth.uid() = student_id);

-- ------------------------------------------------------------
-- 2. Replace submit_quiz() to also require 100% lesson completion.
--    Same signature as patch_01 — this is a straight override.
-- ------------------------------------------------------------
create or replace function public.submit_quiz(p_quiz_id uuid, p_answers jsonb)
returns table (score int, passed boolean, certificate_code text)
language plpgsql
security definer set search_path = public
as $$
declare
  v_user          uuid := auth.uid();
  v_course        uuid;
  v_pass          int;
  v_total         int;
  v_correct       int;
  v_score         int;
  v_passed        boolean;
  v_code          text;
  v_lesson_total  int;
  v_lesson_done   int;
begin
  if v_user is null then
    raise exception 'Not authenticated';
  end if;

  select q.course_id, q.passing_score
    into v_course, v_pass
  from quizzes q
  where q.id = p_quiz_id;

  if v_course is null then
    raise exception 'Quiz not found';
  end if;

  select count(*) into v_lesson_total
  from lessons l
  join modules m on m.id = l.module_id
  where m.course_id = v_course;

  select count(distinct lp.lesson_id) into v_lesson_done
  from lesson_progress lp
  join lessons l on l.id = lp.lesson_id
  join modules m on m.id = l.module_id
  where m.course_id = v_course and lp.student_id = v_user;

  if v_lesson_total > 0 and v_lesson_done < v_lesson_total then
    raise exception 'Complete all % lessons before taking the test (% done)',
      v_lesson_total, v_lesson_done;
  end if;

  select count(*) into v_total
  from questions
  where quiz_id = p_quiz_id;

  select count(*) into v_correct
  from questions qs
  where qs.quiz_id = p_quiz_id
    and (p_answers ->> qs.id::text)::int = qs.correct_index;

  v_score := case when v_total = 0 then 0
                  else round((v_correct::numeric / v_total) * 100) end;
  v_passed := v_score >= v_pass;

  insert into quiz_attempts (student_id, quiz_id, score, passed)
  values (v_user, p_quiz_id, v_score, v_passed);

  if v_passed then
    insert into certificates (student_id, course_id)
    values (v_user, v_course)
    on conflict (student_id, course_id) do nothing;

    select c.certificate_code into v_code
    from certificates c
    where c.student_id = v_user and c.course_id = v_course;
  end if;

  return query select v_score, v_passed, v_code;
end;
$$;

revoke all on function public.submit_quiz(uuid, jsonb) from public, anon;
grant execute on function public.submit_quiz(uuid, jsonb) to authenticated;

-- ################################################################
-- PART: patch_03_approval_flow.sql
-- ################################################################
-- ============================================================
-- Patch 03 — categories, admin approval, access-gated content
-- Run AFTER schema.sql, the seeds, patch_01 and patch_02.
-- Safe to re-run.
--
-- Flow this enables:
--   register -> browse courses by category -> request access
--   -> admin approves -> student sees the course, learns day by day
--   -> finishes every lesson -> takes the test -> passes -> certificate
-- ============================================================

-- ------------------------------------------------------------
-- 1. Categories (courses are grouped by these in the catalog)
-- ------------------------------------------------------------
create table if not exists categories (
  id          uuid primary key default gen_random_uuid(),
  slug        text unique not null,
  name        text not null,
  order_index int not null default 0
);

alter table categories enable row level security;
drop policy if exists "categories read" on categories;
create policy "categories read" on categories for select using (true);

alter table courses add column if not exists category_id uuid references categories(id) on delete set null;

insert into categories (slug, name, order_index) values
  ('web-development', 'Web Development', 1),
  ('ai-data-science', 'AI & Data Science', 2),
  ('general', 'General', 99)
on conflict (slug) do nothing;

-- put the two existing courses in a category (only if not set yet)
update courses set category_id = (select id from categories where slug = 'web-development')
 where slug = 'mern-stack-foundations' and category_id is null;
update courses set category_id = (select id from categories where slug = 'ai-data-science')
 where slug = 'python-for-ai-21-days' and category_id is null;
-- anything else uncategorised lands in General
update courses set category_id = (select id from categories where slug = 'general')
 where category_id is null;

-- ------------------------------------------------------------
-- 2. Admins. A separate table, NOT a flag on profiles: students can
--    update their own profile row, so a profiles.is_admin column
--    would let anyone promote themselves.
--    RLS is on with no policies, so the API can never read or write it.
-- ------------------------------------------------------------
create table if not exists admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);
alter table admins enable row level security;

create or replace function public.is_admin()
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;
grant execute on function public.is_admin() to anon, authenticated;

-- ------------------------------------------------------------
-- 3. Profiles: keep the email so the admin can tell students apart
-- ------------------------------------------------------------
alter table profiles add column if not exists email text;

update profiles p set email = u.email
from auth.users u
where u.id = p.id and p.email is null;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, stream, college, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce(new.raw_user_meta_data->>'stream', 'Other'),
    new.raw_user_meta_data->>'college',
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop policy if exists "profile admin read" on profiles;
create policy "profile admin read" on profiles for select using (public.is_admin());

-- ------------------------------------------------------------
-- 4. Enrollments become requests: pending -> approved / rejected
-- ------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'enrollments' and column_name = 'status'
  ) then
    alter table enrollments
      add column status text not null default 'pending'
        check (status in ('pending', 'approved', 'rejected')),
      add column reviewed_at timestamptz,
      add column reviewed_by uuid references auth.users(id);

    -- One-time: enrollments that existed before this patch were already
    -- active students, so keep them approved.
    update enrollments set status = 'approved', reviewed_at = now();
  end if;
end $$;

drop policy if exists "enrollments self all"     on enrollments;
drop policy if exists "enrollments self read"    on enrollments;
drop policy if exists "enrollments self request" on enrollments;
drop policy if exists "enrollments self cancel"  on enrollments;
drop policy if exists "enrollments admin read"   on enrollments;
drop policy if exists "enrollments admin update" on enrollments;

-- a student sees their own requests
create policy "enrollments self read" on enrollments
  for select using (auth.uid() = student_id);

-- ...and can only ever file a PENDING request for themselves
create policy "enrollments self request" on enrollments
  for insert with check (
    auth.uid() = student_id and status = 'pending'
    and reviewed_at is null and reviewed_by is null
  );

-- ...and may withdraw a pending/rejected request (to re-request later),
-- but can never touch an approved one
create policy "enrollments self cancel" on enrollments
  for delete using (auth.uid() = student_id and status in ('pending', 'rejected'));

-- only admins review requests
create policy "enrollments admin read" on enrollments
  for select using (public.is_admin());
create policy "enrollments admin update" on enrollments
  for update using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- 5. Who may open a course's content?  Approved students + admins.
-- ------------------------------------------------------------
create or replace function public.has_course_access(p_course uuid)
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select public.is_admin()
      or exists (
        select 1 from public.enrollments e
        where e.student_id = auth.uid()
          and e.course_id  = p_course
          and e.status     = 'approved'
      );
$$;
grant execute on function public.has_course_access(uuid) to anon, authenticated;

-- lesson bodies and videos are only readable with access
drop policy if exists "lessons read" on lessons;
create policy "lessons read" on lessons for select using (
  exists (
    select 1 from modules m join courses c on c.id = m.course_id
    where m.id = lessons.module_id and c.is_published
      and public.has_course_access(c.id)
  )
);

-- questions follow the same rule
create or replace view questions_public as
select qs.id, qs.quiz_id, qs.question, qs.options, qs.order_index
from questions qs
join quizzes q on q.id = qs.quiz_id
join courses c on c.id = q.course_id
where c.is_published and public.has_course_access(c.id);
grant select on questions_public to authenticated;

-- A public syllabus (titles only, no content/video) so a student can see
-- what a course covers BEFORE requesting it.
create or replace view lesson_outline as
select l.id, l.module_id, l.title, l.order_index
from lessons l
join modules m on m.id = l.module_id
join courses c on c.id = m.course_id
where c.is_published;
grant select on lesson_outline to anon, authenticated;

-- ------------------------------------------------------------
-- 6. Pass mark is 40% (a student needs 40% or more)
-- ------------------------------------------------------------
alter table quizzes alter column passing_score set default 40;
update quizzes set passing_score = 40;

-- ------------------------------------------------------------
-- 7. submit_quiz(): add "approved for this course" on top of the
--    patch_02 rules (all lessons done, server-side scoring).
-- ------------------------------------------------------------
create or replace function public.submit_quiz(p_quiz_id uuid, p_answers jsonb)
returns table (score int, passed boolean, certificate_code text)
language plpgsql
security definer set search_path = public
as $$
declare
  v_user          uuid := auth.uid();
  v_course        uuid;
  v_pass          int;
  v_total         int;
  v_correct       int;
  v_score         int;
  v_passed        boolean;
  v_code          text;
  v_lesson_total  int;
  v_lesson_done   int;
begin
  if v_user is null then
    raise exception 'Not authenticated';
  end if;

  select q.course_id, q.passing_score
    into v_course, v_pass
  from quizzes q
  where q.id = p_quiz_id;

  if v_course is null then
    raise exception 'Quiz not found';
  end if;

  if not public.has_course_access(v_course) then
    raise exception 'Your access to this course has not been approved yet';
  end if;

  select count(*) into v_lesson_total
  from lessons l
  join modules m on m.id = l.module_id
  where m.course_id = v_course;

  select count(distinct lp.lesson_id) into v_lesson_done
  from lesson_progress lp
  join lessons l on l.id = lp.lesson_id
  join modules m on m.id = l.module_id
  where m.course_id = v_course and lp.student_id = v_user;

  if v_lesson_total > 0 and v_lesson_done < v_lesson_total then
    raise exception 'Complete all % lessons before taking the test (% done)',
      v_lesson_total, v_lesson_done;
  end if;

  select count(*) into v_total
  from questions
  where quiz_id = p_quiz_id;

  select count(*) into v_correct
  from questions qs
  where qs.quiz_id = p_quiz_id
    and (p_answers ->> qs.id::text)::int = qs.correct_index;

  v_score := case when v_total = 0 then 0
                  else round((v_correct::numeric / v_total) * 100) end;
  v_passed := v_score >= v_pass;

  insert into quiz_attempts (student_id, quiz_id, score, passed)
  values (v_user, p_quiz_id, v_score, v_passed);

  if v_passed then
    insert into certificates (student_id, course_id)
    values (v_user, v_course)
    on conflict (student_id, course_id) do nothing;

    select c.certificate_code into v_code
    from certificates c
    where c.student_id = v_user and c.course_id = v_course;
  end if;

  return query select v_score, v_passed, v_code;
end;
$$;

revoke all on function public.submit_quiz(uuid, jsonb) from public, anon;
grant execute on function public.submit_quiz(uuid, jsonb) to authenticated;

-- ------------------------------------------------------------
-- 7b. Admin dashboard numbers: admins may read certificates and attempts
-- ------------------------------------------------------------
drop policy if exists "certificates admin read" on certificates;
create policy "certificates admin read" on certificates for select using (public.is_admin());
drop policy if exists "attempts admin read" on quiz_attempts;
create policy "attempts admin read" on quiz_attempts for select using (public.is_admin());

-- ------------------------------------------------------------
-- 8. MAKE YOURSELF ADMIN (run once, after you have signed up):
--
--   insert into admins (user_id)
--   select id from auth.users where email = 'YOUR_EMAIL_HERE'
--   on conflict do nothing;
-- ------------------------------------------------------------
