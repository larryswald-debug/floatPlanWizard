# Page snapshot

```yaml
- generic [active] [ref=e1]:
  - generic [ref=e2]:
    - button "Close full map" [ref=e3] [cursor=pointer]: ×
    - link "Back to Follow Page" [ref=e4]:
      - /url: http://localhost:8500/fpw/app/follow.cfm
  - generic [ref=e5]:
    - banner [ref=e6]:
      - generic [ref=e7]:
        - paragraph [ref=e8]: Follow Full Map
        - heading "Unable to load map" [level=1] [ref=e9]
        - paragraph [ref=e10]: Use the link below to return to the Trip status page.
    - main [ref=e11]:
      - generic "Full-screen voyage route map" [ref=e12]
      - generic [ref=e13]: No voyage stream matched the provided slug or stream id.
```