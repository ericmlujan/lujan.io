# lujan.io

Source code for the personal website of Eric Lujan (that's me).

![rspec](https://github.com/ericmlujan/lujan.io/actions/workflows/rspec.yml/badge.svg)
![lint](https://github.com/ericmlujan/lujan.io/actions/workflows/lint.yml/badge.svg)

## What exactly have we got here?

In about 2013, I put my first personal website up on the Internet. At the time, Rails was _all the rage_ and I figured I'd take the time to learn the hip new framework that was taking the blogosphere by storm. Rspec? MVC? _ActiveRecord?!_ Totally tubular! Programming can be fun again! Where do I sign?!

It turns out making a blogging application is, like, _the_ thing Rails was built to do, and naturally every Rails tutorial was either about making a Twitter clone or a library inventory system. So I fired up my build of TextMate and got to work following the steps. I was a monkey, my laptop was a typewriter, and _The Complete Works of William Shakespeare_ were about to be written.

The result, after much heming and hawing and realising my own incompetence in rote copying from a tutorial, was a half-functional website. Never mind logging into Twitter... I could log into my own blog _using_ Twitter. I even introduced guest post functionality at one point, so people funnier than I could host their musings on my domain.

And... that was about it for a while. Yet another blog in the foaming ocean of bytes that, then as now, is mostly spent buffering ill-conceived Netflix original programming.

### Aside: a (somewhat) amusing story

> I _do_ have a funny story involving lujan.io 1.0. My freshman year of college, I took what I thought was a frontend design interview at a startup. Hope in my eyes, I walked into the interview room and accepted the Nespresso the engineer graciously offered me. He left the room to grab the drink and I anxiously shuffled in my chair.
>
> When he returned, he handed me a mug and plunked down a laptop on the table in front of me. He opened the lid, and the blank screen flickered to life to reveal none other than a fullscreen Chrome tab of my site.
>
> "We were looking at your website and couldn't help but notice that the browser lags every time you scroll. As an initial exercise, it would be awesome to see how you'd approach diagnosing such an issue and recommending a fix."
>
> "Uh... yeah... the lagging scrolling..."
>
> To my dismay, my first potential employer had discovered the issue I'd been scratching my head about for about six months. And now I was to solve it in 10 minutes.
>
> I clumsily opened the web inspector and reloaded the page a few times, clicking through the tracing info it spat out. My memory is hazy on exactly what I said, but judging by the puzzled look on my interviewer's face and my subsequent rejection, it wasn't satisfactory.
>
> In retrospect, it was probably the 4800px-wide uncompressed JPEG I had decided to set as the background attribute of the navbar I pinned to the top of the browser viewport. _Ah, the naivete of youth._

Since then, I've always picked at my website and attempted rewrites of it in fits and starts. When Nodejs really took off, I learned Express and tried to dive headfirst into the one-language-to-rule-them-all future (never mind that that was what Java tried to be, JavaScript is like that, but with fewer types, fewer factories, and a hell of a lot more Script). At one point I thought it would be hip to write this as a fully browser-rendered SPA in React and actually made quite a go of it before realising how silly that would be.

Despite my tendency to overengineer my personal projects, I don't need something trendy or fancy for what is essentially an online business card. I need something that loads quickly, something that's minimalist, something that's accessible and will work even in somewhat old versions of Internet Explorer, if that's what someone chooses to load my site in.

Recently, I've been thinking about how it would be nice to get a little closer to my programming roots. How it would be good to have a pleasant balance to my day job of writing C++. A meditative escape through code.

Even though it's 2021 at the time of writing, _I still like Ruby._ I missed writing it. It's idealistic. It's a little idiosyncratic. _It makes programming fun again._ And for something targeted towards my spare time, it's a natural fit.

But I don't need the heaviness of Rails. This website will never be Twitter, nor should it be. I want something with _just_ enough functionality to be fun to build from the ground up without getting in the way of the joy of code.

## None of that is about this codebase. Again, what exactly have we got here?

At its heart, this codebase is two things:

1. Some ERB and CSS that serve mostly as an online business card and short biography for me.
2. An excuse to write the core of a minimalist web framework from the ground up.

The first bullet point is fairly boring, so I'll talk more on the second.

At its heart, this application is built atop Rack, but I've written my own routing, view rendering, and redirection logic instead of using any additional frameworks.

This logic, which you can see applied in [app.rb](lujan.io/app.rb) is a DSL whose syntax is ~~lifted from~~ heavily inspired by [Sinatra](http://sinatrarb.com) and Gary Bernhardt's excellent From Scratch screencasts at [Destroy All Software](https://destroyallsoftware.com).

At present, this DSL defines three main primitives:

**Routes:** Declared by a keyword corresponding to an HTTP verb (i.e. `get`), followed by two arguments, a path specification, and a block. In response to a request with a matching path and HTTP verb, the block will be evaluated and its return value will become the body of the HTTP response.

**Static assets:** Declared by the `static` keyword, followed by the path to a local directory containing static assets, like CSS, images, or any JavaScript. The application will attempt to serve assets in the static directory in response to GET requeests at the same relative path to the root URI. For example, if `./public` is set to a static directory, a GET request to `https://lujan.io/main.css` will serve `./public/main.css`.

**Redirects:** Declared by the `redirect` keyword, followed by a path specification and a URI. GET requests matching the path specification will cause a 302 to the corresponding URI. Doesn't get much simpler than that.

## Building

See [the Gemfile](./lujan.io/Gemfile) for the required version of Ruby.

To install dependencies, run Bundler from the `lujan.io` directory.

```sh
$ cd lujan.io
$ bundle
```

To run this in a local dev environment, simply start Rack as usual.

```sh
$ rackup
```

RSpec tests also work as one would expect if run from the `lujan.io` directory.

```sh
$ cd lujan.io
$ bundle exec rspec spec/
```

Because I'm hip and modern (and like being able to test my deployments) Docker is supported for this repo.

```sh
$ cd lujan.io
$ docker build . -t lujan.io
```

Running with Let's Encrypt certificate refreshing and Nginx under docker-compose is also supported.

```sh
$ docker-compose build && docker-compose up
```

The Nginx config expects an SSL certificate to already be generated, so an [initial verification with Let's Encrypt](https://certbot.eff.org/instructions) using one of the available methods is required. Once the Certbot directory (the one that contains `live/`) is plunked in `secrets/`, Nginx should start without crashing and automatic certificate renewal with Certbot should work.
