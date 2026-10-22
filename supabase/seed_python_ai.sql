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
