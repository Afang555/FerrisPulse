# 项目网站与搜索收录维护

项目网站：https://afang555.github.io/FerrisPulse/

## 发布与内容

GitHub Pages 使用 `MetapandaMouse05` 分支的 `/docs` 目录；`docs/index.html` 是静态介绍页，`.nojekyll` 禁用 Jekyll 处理。页面包含中文标题与描述、canonical、Open Graph 和 SoftwareApplication JSON-LD。结构化数据不保证搜索结果展示增强样式。

发布版本变化时同步首页版本、发布链接、便携包链接、JSON-LD softwareVersion 和 sitemap.xml 的实际更新时间。保持 README、使用指南与首页的设备范围一致；实机反馈标明来源和限制，不虚构评分或下载量。

## Google 与 Bing 所有权验证

1. Google Search Console 添加 URL 前缀资源 `https://afang555.github.io/FerrisPulse/`，选择 HTML 标签验证。
2. 将 Google 提供的 `google-site-verification` meta 标签加入 `docs/index.html` 的 head，推送发布后回控制台验证。
3. Bing Webmaster Tools 添加同一 URL，选择 HTML 标签，将 `msvalidate.01` meta 标签加入 head；也可按控制台流程从已验证的 Search Console 导入。
4. 验证后提交 `https://afang555.github.io/FerrisPulse/sitemap.xml`，检查首页 URL 并按控制台提供的功能请求收录。
5. 验证标签需长期保留；只需公开验证标签，不需要账号密码、访问令牌或会话 Cookie。

Google 验证标签已按用户提供的内容加入首页 head，需长期保留；等待用户在 Search Console 点击验证并确认结果。Bing 标签尚未提供。不能据标签发布宣称已完成站长验证、提交收录或已经被索引。HTTP 200 和网站发布成功只表示页面可以访问。抓取、收录、排名与实际搜索流量分别判断。

项目位于 github.io 的 /FerrisPulse/ 子路径，不能通过此仓库管理域名根目录的 robots.txt，不在子路径放置无效 robots.txt 来宣称控制全站抓取。sitemap 通过站长后台提交。

## 核对方式

- 页面公开返回 HTTP 200，没有 noindex；正文、下载链接和兼容范围无需 JavaScript 即可读取。
- 检查 canonical 与 sitemap 指向公开地址，JSON-LD 可解析，版本与 version.json 一致。
- Search Console 使用 URL 检查和索引报告；Bing 使用 URL Inspection。普通搜索结果与 site: 查询仅作为辅助，不代替控制台状态。
- 外部介绍链接应真实相关，可在维护者个人主页或实际介绍本工具的文章中引用；不购买垃圾外链或堆叠重复关键词。

## 官方参考

- [GitHub Pages 发布目录](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)
- [Google SEO 入门](https://developers.google.com/search/docs/fundamentals/seo-starter-guide)
- [Google 所有权验证](https://support.google.com/webmasters/answer/9008080)
- [Google 请求重新抓取](https://developers.google.com/search/docs/crawling-indexing/ask-google-to-recrawl)
- [Bing 添加及验证网站](https://www.bing.com/webmasters/help/add-and-verify-site-12184f8b)