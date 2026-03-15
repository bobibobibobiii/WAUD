# WAUD 网页版部署（用于 PakePlus 打包）

## 目标

把 Flutter Web 构建产物部署成一个可公网访问的 HTTPS URL，用于在 PakePlus 中填写并打包为手机 App。

## 推荐方案：GitHub Pages（自动部署）

1. 新建一个 GitHub 仓库并把当前项目推送上去（仓库名建议用 waud 或你喜欢的名字）。
2. 仓库默认分支使用 `main` 或 `master`（两者都支持）。
3. 在 GitHub 仓库里打开：
   - Settings → Pages
   - Build and deployment → Source：选择 “GitHub Actions”
4. 推送代码后会自动触发工作流：
   - `.github/workflows/deploy-gh-pages.yml`
5. 部署成功后，Pages 会给出最终访问地址：
   - `https://<你的GitHub用户名>.github.io/<仓库名>/`

这个 URL 直接填入 PakePlus 即可打包。

## 备用方案：任意静态托管

1. 本地执行 `flutter build web --release`
2. 把 `build/web` 作为静态网站目录上传到任意静态托管（Cloudflare Pages / Vercel / Nginx 等）
3. 拿到托管平台提供的 HTTPS URL 后填入 PakePlus
