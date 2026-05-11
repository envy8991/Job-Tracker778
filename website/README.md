# Job Tracker Website

The production-style browser app lives in [`website/app/`](app/). The files at the root of `website/` are only compatibility entry points so older links to `/website/` redirect into the single Firebase-backed web app shell.

## Run locally

From the repository root:

```sh
python3 -m http.server 8000 --directory website
```

Then open <http://localhost:8000/app/>.
