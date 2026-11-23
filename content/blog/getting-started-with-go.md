---
title: Start Being a Gopher
description:
  A practical, no-BS guide to starting with Go with real commands, real code and zero tutorial hell.
tags:
  - golang
  - programming
  - backend
  - CLI/TUI
  - programming languages
date: 2026-03-24
image: /start-being-a-gopher.png
---

## Introduction

> Is Go worth learning?

Wrong question.

The better one is:

**"Do I need Go for what I'm trying to build right now?"**

Because what usually happens is simple: you watch tutorials, compare Go vs Rust
vs Node, save 20 tabs… and write nothing.

This post is not about convincing you. It's about getting you started fast,
practical, and without wasting time.

## What Go Is Actually Good At

Go is built for:

- APIs and backend services
- CLI/TUI tools (tbh here this is one of the most beautiful things)
- networking / distributed systems

If that is what you are building keep reading. If not maybe you dont need Go.

---

## Install Go (Do This First Not Later)

Don't skip this part.

## Install for Linux Distros. (come to me linux mate)

### Arch Linux / CachyOS / EndeavourOS

```bash
sudo pacman -S go
```

### Fedora

```bash
sudo dnf install golang
```

### openSUSE (Tumbleweed / Leap)

```bash
sudo zypper install go
```

### Debian / Ubuntu

```bash
sudo apt update
sudo apt install golang
```

### or cross-distro installation

if you want the latest version always this is a hacky command i made to install
the latest version:

```bash
GO_TAR=$(curl -s https://go.dev/VERSION?m=text | head -n 1).linux-amd64.tar.gz
wget https://go.dev/dl/$GO_TAR
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf $GO_TAR
rm -rf $GO_TAR
```

then Add `Go bin` to the path:

```bash
export PATH=$PATH:/usr/local/go/bin
```

and if you want it always available:

```bash
# this command adds Go to PATH (compiler + installed tools)
# also you should use bash shell, if not just Ask ai to give you the command XD
echo 'export PATH=$PATH:/usr/local/go/bin:$(go env GOPATH)/bin' >> ~/.bashrc
source ~/.bashrc
```

### macOS

Using Homebrew:

```bash
brew install go
```

### Windows

Download installer from: **https://go.dev/dl/**

Run it. Done.

### Verify Installation

```bash
go version
```

If it prints a version, you're good.

---

## Some resources for my beloved reader

Go have a good and well documented resources, but the official one sometimes feels distructing for the new gophers.
so let me give you how to learn from the official docs and unofficial resources.

### The Go.dev

first you have 3 ways in go.dev to learn:

1. A Tour Of Go

- go have great interactive tutorial named ["A Tour Of Go"](https://go.dev/tour/) you can finish all Go basics and concepts on it.

> like what they said: An interactive introduction to Go in four sections. The first section covers basic syntax and data structures; the second discusses methods and interfaces; the third is about Generics; and the fourth introduces Go's concurrency primitives. Each section concludes with a few exercises so you can practice what you've learned.

::callout{type="note"}
You can take the [tour online](https://go.dev/tour/). or install it locally with `go install golang.org/x/website/tour@latest`
::

2. Go tutorial

- this is a Step by step guides for specific tasks, such as getting started with modules, creating multi-module workspaces, or accessing a database. after you finish the tour of go one you can start with it. (i did that)
- you can access it [here](https://go.dev/doc/tutorial/).

3. Effective Go

- After grasping the language basics, this document helps you understand how to write clear and idiomatic Go code (like yeah the "Go way").
- you can access it [here](https://go.dev/doc/effective_go).
- Its a bunch of sections on one page but you will be satisfied with it XD

::callout{type="tip"}
you will not be comfortable with go and will not like it if you didnt learned how to write clear and idiomatic go code and same if you fight its opinions.
::

After that i guess you will beat me in Go (you can't though, tbh XD)

### The Go.community

Go community is very good and helpful and creates alot of OSS projects while keeping it well documented such as [charmTM](https://charm.land) i love this team and their community, they helped me alot about go and even with positive energy XD, and some other made a good resources for golang such like:

- [Go By Example](https://gobyexample.com/): is a hands-on introduction to Go using annotated example programs.
- [Exercism for Gophers](https://exercism.org/tracks/go): its a good course for those who likes the video learning way (i dont like it but others may do) it have "164 exercises grouped into 34 Go Concepts, with automatic analysis of your code and personal mentoring, all 100% free." — by them.
- [Awesome Go](https://awesome-go.com/): A curated list of awesome Go frameworks, libraries, and software. Inspired by awesome-python.
- [Learn X in Y minutes](https://learnxinyminutes.com/go): Where X=Go XDD.
- [Go101](https://go101.org/): (an up-to-date knowledge base for Go programming self learning).
- [Another go by example](https://www.mintlify.com/mmcgrana/gobyexample): A beautiful and modern docs-like go by example and have Ask-ai feature.
- [Learn Go with tests](https://quii.gitbook.io/learn-go-with-tests): a good resource to learn test-driven development with Go and it have Go fundamentals section.

### The Go.books

Seeeeeigh there is alot here but i will put books libraries:

- [The Go Programming Language](http://www.cs.uniroma2.it/upload/2017/TSC/The%20Go%20Programming%20Language.pdf): this is like the official book but its not, and its very good.
- [Awesome Go books](https://github.com/dariubs/GoBooks): GoBooks is a curated collection of the best Go books for developers at every level—from beginners to engineers working on concurrency, performance, and system design. One place to find the right learning resource.
- [Go Wiki books](https://go.dev/wiki/Books): the official list of books by `go.dev`.

## Your First Go Program

Create a file:

```bash
mkdir hello-go && cd hello-go
touch main.go
```

Put this inside:

```go [hello.go]
package main

import "fmt"

func main() {
    fmt.Println("hello from Samouly, gopher!")
}
```

Run it:

```bash
go run main.go
```

## Manage Your Project (The `go mod` way)

Forget the old `GOPATH` nightmare. In modern Go, every project needs a
**Module**. It’s like a `package.json` for Go. It tells the compiler (and your
LSP) where the dependencies are.

In your project folder, run:

```bash
go mod init my-awesome-project
```

This creates a `go.mod` file. From this moment:

- Your **LSP** will actually work.
- You can import local packages.
- You can add external libraries using `go get`.

::callout{type="warning"}
If you don't run `go mod init`, you are basically coding in a notepad without any "intelligence" from your tools. Dont be that person.
::

## Build a Binary (Where Go Shines XD)

```bash
go build
./hello-go
```

::callout{type="tip"}
Binary Naming If you run go build **(without specifying a file)**, Go will name the binary after your directory. If you build a specific file like `go build main.go` it will be named `main`.
::

Now you have a standalone binary. No runtime. No dependencies. Just run it.

---

## The Only Concepts You Need to Start

Don't try to learn everything. Focus on these:

### 1. Packages

Everything in Go is a package. Think of it like folders in your file system
every file belongs to a package, and that's how Go organizes code.

```go
import "fmt"
```

Here `fmt` is the standard formatting package. You use it for printing to
console, formatting strings, all that basics. There's hundreds in the standard
library, but you only need a handful to start.

::card{icon="i-simple-icons-go" title="The package rule"}
Every Go file MUST start
with a package declaration. For executables, use `package main`. For libraries,
use whatever name fits like `package utils` or `package models`.
::

### 2. Functions

Functions in Go are straightforward. You define what goes in, what comes out.

```go
func add(a int, b int) int {
    return a + b
}
```

That's it. No magic, no decorators, no weird syntax.

#### Function Types

Go dont have overloading, but you have some main patterns worth knowing:

##### **1. Multiple return values**

This is huge in Go. Functions can return both a value AND an error. This is how
Go handles errors you see it everywhere.

```go
func divide(a, b float64) (float64, error) {
    if b == 0 {
        return 0, fmt.Errorf("division by zero")
    }
    return a / b, nil
}
```

The `error` type is Go's built-in way to handle failures. If something goes
wrong, you get an error object. If it worked, you get `nil`. Get used to
checking this pattern it's everywhere in Go code.

---

**2. Named return values**

Go lets you name what you're returning. It's useful when you want to set it
early and return later without specifying.

```go
func rectangle(width, height int) (area int) {
    area = width * height
    return
}
```

You don't have to say `return area` Go knows because you named it. Some people
love this, some hate it. I use it when the function is long and setting the
return value early makes the code clearer.

---

**3. Variadic functions**

These accept any number of arguments. The `...` syntax is the magic.

```go
func sum(nums ...int) int {
    total := 0
    for _, n := range nums {
        total += n
    }
    return total
}
```

You can call it with `sum(1, 2, 3)` or `sum(1, 2, 3, 4, 5)` any amount. Super
useful for things like logging, building queries, anywhere you might need
flexible arguments.

---

**4. Anonymous functions**

Functions don't need a name. You can define them inline and even call them
immediately.

```go
func main() {
    result := func(a int, b int) int {
        return a + b
    }(2, 3)

    fmt.Println(result)
}
```

This prints `5`. The function is defined and then called right away with `2, 3`.
Not something you do every day, but useful for quick logic or closures.

---

**5. Higher-order functions**

Functions can take other functions as arguments. This is where things get
flexible.

```go
func operate(a, b int, fn func(int, int) int) int {
    return fn(a, b)
}
```

You pass in the logic you want. Want to add? Pass add. Want to multiply? Pass
multiply. Same function, different behavior. This is the foundation for things
like `map`, `filter`, and `reduce` in Go.

#### Methods & Receivers

Go dont have classes, but you have methods using receivers. This is how you
attach functions to your own types.

**Value Receiver**

When you don't need to modify the original, use value receiver.

```go
type User struct {
    Name string
}

func (u User) greet() string {
    return "Hello " + u.Name
}
```

Call it like `user.greet()`. The function gets a copy of the struct. Good for
read-only operations.

---

**Pointer Receiver**

When you need to modify the original, use pointer receiver.

```go
func (u *User) rename(newName string) {
    u.Name = newName
}
```

The `*User` means it works on the actual struct, not a copy. Changes persist.
This is also more efficient for large structs you're not copying everything.

---

::callout{type="tip"}
When in doubt, start with pointer receiver. It's more common in real code and avoids surprises with mutations.
::

#### When to Use What

- Use **value receiver** when:
  - you don't need to modify the data
  - the struct is small
  - you want to be safe from accidental changes

- Use **pointer receiver** when:
  - you need to modify the data
  - the struct is large (avoid copying memory)
  - you want to share one instance across multiple calls

### 3. Structs

Structs are Go's way to group related data together. Think of them like
lightweight objects no classes, no inheritance, just data and methods.

```go
type User struct {
    Name string
    Age  int
}
```

That's a user with a name and age. Create one:

```go
var user = User{
	Name: "Alaa",
	Age: 20
}
```

Access fields like `user.Name`. Simple.

You can add methods to structs (that's the receivers we covered). That's where
Go's "composition over inheritance" philosophy comes in you don't inherit, you
just add methods to whatever you need.

### 4. Error Handling

Go's error handling is explicit. No exceptions, no try-catch. You handle errors
as they happen.

```go
if err != nil {
    return err
}
```

You'll see this everywhere. Get used to it.

The pattern is: do something, check if it failed, handle it. No hidden magic. No
surprise crashes. Every function that can fail returns an error you decide what
to do with it.

::callout{type="warning"}
Never ignore errors with `_`. If you do `result, _ := someFunction()`, you're silently swallowing failures. At minimum, log them. Your future self will thank you.
::

### 5. Goroutines and Go channels (Later, not now)

This is Go's concurrency running things in parallel. But don't start here.

```go
go someFunction()
```

It looks simple. Is simple. But using it correctly requires understanding
channels, synchronization, race conditions. All things to learn after you've got
the basics down.

::callout{type="note"}
Concurrency is not parallelism. Go handles both, but start with writing good synchronous code first. Add `go` only when you've proven you need it, i will do another post about that.
::

---

## Build Something Real (Immediately)

Don't stay in "learning mode".

Pick one:

- CLI todo app
- simple REST API
- file server
- log parser

Example: minimal HTTP server

```go
package main

import (
    "fmt"
    "net/http"
)

func handler(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintf(w, "hello from go server")
}

func main() {
    http.HandleFunc("/", handler)
    http.ListenAndServe(":8080", nil)
}
```

Run:

```bash
go run main.go
```

Open:

```
http://localhost:8080
```

That's a running web server in under 20 lines of code. The standard library
gives you this for free.

---

## The Go Mindset

Go has strong opinions about how code should be written. Fight these and you'll
fight the language. Accept them and you'll move fast.

- **Simplicity over cleverness** Go prefers clear code over clever code. If you
  find yourself writing complex abstractions to save a few lines, you're
  probably doing it wrong. The goal is readability, not impressing other
  developers.

- **Explicit over magic** Go doesn't do implicit anything. No hidden type
  conversions, no automatic imports, no magic. What you see is what you get.
  This makes code easier to understand and debug.

- **Composition over inheritance** Forget classes and inheritance hierarchies.
  In Go, you compose behavior by embedding types. It's more flexible and less
  fragile than traditional OOP.

::callout{type="warning"}
If you fight Go's opinions you will hate using it. If you embrace them, you will ship faster than with any other language You have used.
::

---

## Pros & Cons (No sugarcoat XD)

::card-group
  ::card{icon="i-lucide-zap" title="Pros"}

- fast compile time
- simple syntax
- great standard library
- easy deployment (single binary)
- built-in concurrency
  ::

  ::card{icon="i-lucide-alert-triangle" title="Cons"}

- repetitive error handling
- limited abstractions
- not very expressive
- can feel restrictive
  ::
::

---

## The Secret to Actually Learning Go

Most people try to "finish learning" Go before building anything. They watch all
the tutorials, read all the docs, watch all the videos.

That doesn't work.

You learn Go by:

- writing code
- breaking things
- fixing them

That's it. There's no shortcut. The more you struggle, the more you learn.

::callout{type="note"}
Tutorials are great for context, but they don't build skills. Skills come from doing, not watching.
::

---

## My Take

::card-group
  ::card{icon="i-lucide-check-circle" title="Great for"}

- build backend systems
- care about performance and simplicity
- want to ship fast
  ::

  ::card{icon="i-lucide-x-circle" title="Not for"}

- want advanced language features
- enjoy complex abstractions
- are doing AI or heavy data science
  ::
::

So what matters is:

- consistency
- building real things
- solving problems

---

## Conclusion

Stop consuming content, Write code; Your first project will be bad but The next
one will be better, That's the only path.

And if you stick with it long enough you will understand why people like Go.

Not because it's amazing Because it works, but for me its amazing XD.
