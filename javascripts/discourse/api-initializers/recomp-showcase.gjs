import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { apiInitializer } from "discourse/lib/api";
import DiscourseURL from "discourse/lib/url";
import { eq } from "discourse/truth-helpers";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";

const SYSTEM_TAGS = new Set([
  "n64",
  "ps1",
  "ps2",
  "snes",
  "nes",
  "gba",
  "gb",
  "gbc",
  "gamecube",
  "wii",
  "dreamcast",
  "saturn",
  "genesis",
  "xbox",
  "xbox360",
  "dos",
  "pc",
  "arcade",
  "psp",
  "ds",
]);

const METHOD_TAGS = new Set([
  "recomp",
  "decomp",
  "ai-rewrite",
  "playable",
  "wip",
  "60fps",
  "widescreen",
  "hd-textures",
  "tooling",
]);

const CONSOLE_RAIL = [
  { slug: "all", label: "All Systems", badge: "ALL", color: "#38bdf8" },
  { slug: "n64", label: "N64", badge: "N64", color: "#22c55e" },
  { slug: "ps1", label: "PS1", badge: "PS1", color: "#6366f1" },
  { slug: "ps2", label: "PS2", badge: "PS2", color: "#3b82f6" },
  { slug: "gamecube", label: "GameCube", badge: "GCN", color: "#8b5cf6" },
  { slug: "xbox360", label: "Xbox 360", badge: "360", color: "#84cc16" },
  { slug: "snes", label: "SNES", badge: "SNES", color: "#a855f7" },
  { slug: "gba", label: "GBA", badge: "GBA", color: "#7c3aed" },
  { slug: "dreamcast", label: "Dreamcast", badge: "DC", color: "#f97316" },
  { slug: "saturn", label: "Saturn", badge: "SAT", color: "#06b6d4" },
  { slug: "dos", label: "DOS / PC", badge: "DOS", color: "#eab308" },
];

const METHOD_CHIPS = [
  { slug: "recomp", label: "⚡ Static Recomp" },
  { slug: "decomp", label: "🧬 Decomp" },
  { slug: "ai-rewrite", label: "🤖 AI Rewrite" },
  { slug: "playable", label: "🎮 Playable" },
  { slug: "60fps", label: "🔥 60fps+" },
  { slug: "widescreen", label: "🖥️ Widescreen" },
];

function normalizeTagName(tag) {
  return (typeof tag === "string" ? tag : tag?.name || "").toLowerCase();
}

function getCoverUrl(topic) {
  if (!topic) {
    return null;
  }
  if (topic.thumbnails?.length > 0) {
    const preferred =
      topic.thumbnails.find((thumb) => thumb.max_width >= 600) ||
      topic.thumbnails[0];
    if (preferred?.url) {
      return preferred.url;
    }
  }
  return topic.image_url || null;
}

function getSystemTag(topic) {
  const tags = topic?.tags || [];
  for (const tag of tags) {
    const name = normalizeTagName(tag);
    if (SYSTEM_TAGS.has(name)) {
      return name;
    }
  }
  return null;
}

function getMethodTags(topic) {
  const tags = topic?.tags || [];
  return tags
    .map(normalizeTagName)
    .filter((name) => METHOD_TAGS.has(name))
    .slice(0, 3);
}

function stripHtml(html) {
  if (!html) {
    return "";
  }
  return html
    .replace(/<[^>]+>/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/\s+/g, " ")
    .trim();
}

function isShowcaseTopic(topic) {
  if (!topic) {
    return false;
  }
  if (topic.pinned && !getCoverUrl(topic)) {
    return false;
  }
  if ((topic.title || "").startsWith("About the ")) {
    return false;
  }
  return true;
}

class RecompLoader extends Component {
  <template>
    <div class="recomp-loader-wrap" role="status" aria-live="polite">
      <svg
        class="recomp-loader"
        viewBox="0 0 64 64"
        width="48"
        height="48"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        aria-hidden="true"
      >
        <defs>
          <linearGradient id="recomp-loader-grad" x1="0" y1="0" x2="64" y2="64" gradientUnits="userSpaceOnUse">
            <stop offset="0%" stop-color="#22d3ee" />
            <stop offset="50%" stop-color="#818cf8" />
            <stop offset="100%" stop-color="#a855f7" />
          </linearGradient>
        </defs>
        <!-- Corner HUD brackets -->
        <path class="recomp-loader__brackets" d="M6 16V8h8M50 8h8v8M58 48v8h-8M14 56H6v-8" stroke="#38bdf8" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
        <!-- Outer segmented targeting ring -->
        <circle class="recomp-loader__ring-outer" cx="32" cy="32" r="23" stroke="url(#recomp-loader-grad)" stroke-width="2.5" stroke-dasharray="18 8 6 8" stroke-linecap="round" />
        <!-- Inner counter-rotating ring -->
        <circle class="recomp-loader__core" cx="32" cy="32" r="17" stroke="#a855f7" stroke-width="1.4" stroke-dasharray="6 5" stroke-linecap="round" opacity="0.75" />
        <!-- Classic Console D-Pad -->
        <g class="recomp-loader__dpad">
          <path d="M29.5 20 H34.5 Q36 20 36 21.5 V28 H42.5 Q44 28 44 29.5 V34.5 Q44 36 42.5 36 H36 V42.5 Q36 44 34.5 44 H29.5 Q28 44 28 42.5 V36 H21.5 Q20 36 20 34.5 V29.5 Q20 28 21.5 28 H28 V21.5 Q28 20 29.5 20 Z" fill="#111827" stroke="#22d3ee" stroke-width="1.6" stroke-linejoin="round" />
          <circle cx="32" cy="32" r="2.4" fill="#080b12" stroke="#38bdf8" stroke-width="1.1" />
          <path d="M32 22.3 L30.3 25 H33.7 Z" fill="#22d3ee" />
          <path d="M41.7 32 L39 30.3 V33.7 Z" fill="#22d3ee" />
          <path d="M32 41.7 L30.3 39 H33.7 Z" fill="#22d3ee" />
          <path d="M22.3 32 L25 30.3 V33.7 Z" fill="#22d3ee" />
        </g>
      </svg>
      {{#if @label}}
        <span class="recomp-loader__label">{{@label}}</span>
      {{/if}}
    </div>
  </template>
}

class RecompHomepage extends Component {
  @service router;
  @service site;

  @tracked activeSlide = 0;
  @tracked requests = [];
  @tracked aiTooling = [];
  @tracked loadedShelves = false;
  @tracked isPaused = false;

  #timer = null;

  constructor(owner, args) {
    super(owner, args);
    this.loadShelves();
    this.#timer = setInterval(() => {
      if (!this.isPaused && this.featuredTopics.length > 1) {
        this.activeSlide = (this.activeSlide + 1) % this.featuredTopics.length;
      }
    }, 6500);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.#timer) {
      clearInterval(this.#timer);
      this.#timer = null;
    }
  }

  get shouldShow() {
    const { category, tag } = this.args.outletArgs || {};
    if (category || tag) {
      return false;
    }
    const route = this.router.currentRouteName || "";
    return (
      route === "discovery.hot" ||
      route === "discovery.latest" ||
      route === "discovery.top" ||
      route === "discovery.new" ||
      route === "discovery.index"
    );
  }

  get allTopics() {
    return this.args.outletArgs?.model?.list?.topics || [];
  }

  get featuredTopics() {
    const withCover = this.allTopics.filter(
      (t) => isShowcaseTopic(t) && getCoverUrl(t)
    );
    return withCover.slice(0, 4).map((t) => ({
      id: t.id,
      title: t.title,
      url: t.url || `/t/${t.slug}/${t.id}`,
      coverUrl: getCoverUrl(t),
      system: getSystemTag(t) || "recomp",
      methods: getMethodTags(t),
      excerpt: stripHtml(t.excerpt).slice(0, 175),
      replies: Math.max(0, (t.posts_count || 1) - 1),
      likes: t.like_count || 0,
      views: t.views || 0,
    }));
  }

  get currentSlide() {
    if (this.featuredTopics.length === 0) {
      return null;
    }
    const idx = this.activeSlide % this.featuredTopics.length;
    return this.featuredTopics[idx];
  }

  get heroBackdropStyle() {
    const url = this.currentSlide?.coverUrl;
    if (!url) {
      return null;
    }
    return trustHTML(`background-image: url('${encodeURI(url)}')`);
  }

  get totalIndexedCount() {
    return this.allTopics.filter((t) => isShowcaseTopic(t)).length;
  }

  get requestsCategoryUrl() {
    const cat = this.site.categories?.find((c) => c.slug === "requests");
    return cat ? `/c/${cat.slug}/${cat.id}` : "/c/requests";
  }

  get aiToolingCategoryUrl() {
    const cat = this.site.categories?.find((c) => c.slug === "ai-tooling");
    return cat ? `/c/${cat.slug}/${cat.id}` : "/c/ai-tooling";
  }

  async loadShelves() {
    try {
      const [reqData, aiData] = await Promise.all([
        ajax(`${this.requestsCategoryUrl}.json`),
        ajax(`${this.aiToolingCategoryUrl}.json`),
      ]);

      const reqTopics = (reqData?.topic_list?.topics || [])
        .filter((t) => isShowcaseTopic(t))
        .slice(0, 4)
        .map((t) => ({
          id: t.id,
          title: t.title.replace(/^\[Request\]\s*/i, ""),
          url: `/t/${t.slug}/${t.id}`,
          system: getSystemTag(t) || "recomp",
          votes: t.vote_count || 0,
          replies: Math.max(0, (t.posts_count || 1) - 1),
          coverUrl: getCoverUrl(t),
        }));

      const aiTopics = (aiData?.topic_list?.topics || [])
        .filter((t) => isShowcaseTopic(t))
        .slice(0, 3)
        .map((t) => ({
          id: t.id,
          title: t.title,
          url: `/t/${t.slug}/${t.id}`,
          system: getSystemTag(t) || "ai",
          methods: getMethodTags(t).slice(0, 2),
          coverUrl: getCoverUrl(t),
        }));

      this.requests = reqTopics;
      this.aiTooling = aiTopics;
      this.loadedShelves = true;
    } catch {
      this.loadedShelves = true;
    }
  }

  @action
  nextSlide() {
    if (this.featuredTopics.length > 0) {
      this.activeSlide = (this.activeSlide + 1) % this.featuredTopics.length;
    }
  }

  @action
  prevSlide() {
    if (this.featuredTopics.length > 0) {
      this.activeSlide =
        (this.activeSlide - 1 + this.featuredTopics.length) %
        this.featuredTopics.length;
    }
  }

  @action
  selectSlide(index) {
    this.activeSlide = index;
  }

  @action
  pauseCarousel() {
    this.isPaused = true;
  }

  @action
  resumeCarousel() {
    this.isPaused = false;
  }

  @action
  goToPath(path, event) {
    event?.preventDefault();
    DiscourseURL.routeTo(path);
  }

  <template>
    {{#if this.shouldShow}}
      <section class="recomp-home">
        {{#if this.currentSlide}}
          <div
            class="recomp-hero"
            {{on "mouseenter" this.pauseCarousel}}
            {{on "mouseleave" this.resumeCarousel}}
          >
            <div class="recomp-hero__bg" style={{this.heroBackdropStyle}}></div>
            <div class="recomp-hero__scrim"></div>

            <div class="recomp-hero__inner">
              <div class="recomp-hero__content">
                <div class="recomp-hero__eyebrow">
                  <span class="recomp-pulse-dot"></span>
                  <span>FEATURED PORT / RECOMP</span>
                  <span
                    class="recomp-system-pill recomp-system-pill--{{this.currentSlide.system}}"
                  >
                    {{this.currentSlide.system}}
                  </span>
                </div>

                <h1 class="recomp-hero__title">
                  <a
                    href={{this.currentSlide.url}}
                    {{on "click" (fn this.goToPath this.currentSlide.url)}}
                  >
                    {{this.currentSlide.title}}
                  </a>
                </h1>

                {{#if this.currentSlide.excerpt}}
                  <p class="recomp-hero__excerpt">
                    {{this.currentSlide.excerpt}}
                  </p>
                {{/if}}

                <div class="recomp-hero__pills">
                  {{#each this.currentSlide.methods as |m|}}
                    <span class="recomp-method-pill recomp-method-pill--{{m}}">
                      {{m}}
                    </span>
                  {{/each}}
                  <span class="recomp-hero__stat">
                    💬 {{this.currentSlide.replies}} replies
                  </span>
                  <span class="recomp-hero__stat">
                    👁 {{this.currentSlide.views}} views
                  </span>
                </div>

                <div class="recomp-hero__actions">
                  <a
                    href={{this.currentSlide.url}}
                    class="recomp-btn recomp-btn--primary"
                    {{on "click" (fn this.goToPath this.currentSlide.url)}}
                  >
                    Inspect Release →
                  </a>
                  <a
                    href={{this.requestsCategoryUrl}}
                    class="recomp-btn recomp-btn--ghost"
                    {{on "click" (fn this.goToPath this.requestsCategoryUrl)}}
                  >
                    ▲ Vote on Bounties
                  </a>
                  <a
                    href={{this.aiToolingCategoryUrl}}
                    class="recomp-btn recomp-btn--ghost"
                    {{on "click" (fn this.goToPath this.aiToolingCategoryUrl)}}
                  >
                    🤖 AI Rewrites
                  </a>
                </div>
              </div>

              <div class="recomp-hero__preview-wrap">
                <a
                  href={{this.currentSlide.url}}
                  class="recomp-hero__preview"
                  {{on "click" (fn this.goToPath this.currentSlide.url)}}
                >
                  <img
                    src={{this.currentSlide.coverUrl}}
                    alt={{this.currentSlide.title}}
                  />
                </a>

                <div class="recomp-hero__controls">
                  <button
                    type="button"
                    class="recomp-hero__nav-btn"
                    aria-label="Previous featured"
                    {{on "click" this.prevSlide}}
                  >
                    ‹
                  </button>
                  <div class="recomp-hero__dots">
                    {{#each this.featuredTopics as |slide idx|}}
                      <button
                        type="button"
                        class="recomp-hero__dot {{if (eq idx this.activeSlide) 'is-active'}}"
                        aria-label="Slide {{idx}}"
                        {{on "click" (fn this.selectSlide idx)}}
                      ></button>
                    {{/each}}
                  </div>
                  <button
                    type="button"
                    class="recomp-hero__nav-btn"
                    aria-label="Next featured"
                    {{on "click" this.nextSlide}}
                  >
                    ›
                  </button>
                </div>
              </div>
            </div>
          </div>
        {{/if}}

        <div class="recomp-rail-wrap">
          <div class="recomp-console-rail">
            {{#each CONSOLE_RAIL as |sys|}}
              <a
                href={{if (eq sys.slug "all") "/hot" (concat "/tag/" sys.slug)}}
                class="recomp-rail-pill"
                style={{trustHTML (concat "--rail-accent:" sys.color)}}
                {{on
                  "click"
                  (fn
                    this.goToPath
                    (if (eq sys.slug "all") "/hot" (concat "/tag/" sys.slug))
                  )
                }}
              >
                <span class="recomp-rail-pill__badge">{{sys.badge}}</span>
                <span class="recomp-rail-pill__label">{{sys.label}}</span>
              </a>
            {{/each}}
          </div>

          <div class="recomp-method-strip">
            <span class="recomp-method-strip__label">Browse by method:</span>
            {{#each METHOD_CHIPS as |chip|}}
              <a
                href="/tag/{{chip.slug}}"
                class="recomp-chip-link"
                {{on "click" (fn this.goToPath (concat "/tag/" chip.slug))}}
              >
                {{chip.label}}
              </a>
            {{/each}}
          </div>
        </div>

        {{#if this.loadedShelves}}
          <div class="recomp-bento">
            <div class="recomp-bento__panel recomp-bento__panel--requests">
              <div class="recomp-bento__header">
                <div>
                  <span class="recomp-bento__kicker">COMMUNITY VOTING</span>
                  <h2>🏆 Top Bounties & Port Requests</h2>
                </div>
                <a
                  href={{this.requestsCategoryUrl}}
                  class="recomp-bento__more"
                  {{on "click" (fn this.goToPath this.requestsCategoryUrl)}}
                >
                  All Requests →
                </a>
              </div>

              <div class="recomp-bounty-list">
                {{#each this.requests as |req|}}
                  <a
                    href={{req.url}}
                    class="recomp-bounty-row"
                    {{on "click" (fn this.goToPath req.url)}}
                  >
                    <div class="recomp-bounty-row__votes">
                      <span class="recomp-bounty-row__arrow">▲</span>
                      <span>{{req.votes}}</span>
                    </div>
                    <div class="recomp-bounty-row__info">
                      <div class="recomp-bounty-row__title">{{req.title}}</div>
                      <div class="recomp-bounty-row__meta">
                        <span
                          class="recomp-system-pill recomp-system-pill--{{req.system}}"
                        >
                          {{req.system}}
                        </span>
                        <span>💬 {{req.replies}} discussion</span>
                      </div>
                    </div>
                  </a>
                {{/each}}
              </div>
            </div>

            <div class="recomp-bento__panel recomp-bento__panel--ai">
              <div class="recomp-bento__header">
                <div>
                  <span class="recomp-bento__kicker">BINARY LIFTING & LLMS</span>
                  <h2>🤖 AI Rewrites & Tooling</h2>
                </div>
                <a
                  href={{this.aiToolingCategoryUrl}}
                  class="recomp-bento__more"
                  {{on "click" (fn this.goToPath this.aiToolingCategoryUrl)}}
                >
                  Explore →
                </a>
              </div>

              <div class="recomp-ai-list">
                {{#each this.aiTooling as |item|}}
                  <a
                    href={{item.url}}
                    class="recomp-ai-row"
                    {{on "click" (fn this.goToPath item.url)}}
                  >
                    {{#if item.coverUrl}}
                      <img
                        src={{item.coverUrl}}
                        alt={{item.title}}
                        class="recomp-ai-row__thumb"
                      />
                    {{/if}}
                    <div class="recomp-ai-row__info">
                      <div class="recomp-ai-row__title">{{item.title}}</div>
                      <div class="recomp-ai-row__tags">
                        <span
                          class="recomp-system-pill recomp-system-pill--{{item.system}}"
                        >
                          {{item.system}}
                        </span>
                        {{#each item.methods as |m|}}
                          <span class="recomp-method-pill recomp-method-pill--{{m}}">
                            {{m}}
                          </span>
                        {{/each}}
                      </div>
                    </div>
                  </a>
                {{/each}}
              </div>
            </div>
          </div>
        {{else}}
          <div class="recomp-bento-loading">
            <RecompLoader @label="SYNCING BOUNTIES & AI REWRITES..." />
          </div>
        {{/if}}

        <div class="recomp-feed-header">
          <div class="recomp-feed-header__left">
            <span class="recomp-bento__kicker">LIVE CATALOG</span>
            <h2>🔥 Trending Recomps, Decomps & Ports</h2>
          </div>
          <div class="recomp-feed-header__right">
            <span class="recomp-feed-count">
              {{this.totalIndexedCount}} active entries
            </span>
          </div>
        </div>
      </section>
    {{/if}}
  </template>
}

class RecompTopicCard extends Component {
  @service router;

  get topic() {
    return this.args.outletArgs?.topic;
  }

  get coverUrl() {
    return getCoverUrl(this.topic);
  }

  get systemTag() {
    return getSystemTag(this.topic);
  }

  get methodTags() {
    return getMethodTags(this.topic).slice(0, 2);
  }

  get replyCount() {
    const posts = this.topic?.posts_count || 1;
    return Math.max(0, posts - 1);
  }

  get excerptHtml() {
    const raw = this.topic?.excerpt;
    return raw ? trustHTML(raw) : null;
  }

  get cardStyle() {
    if (!this.coverUrl) {
      return null;
    }
    return trustHTML(`background-image: url('${encodeURI(this.coverUrl)}')`);
  }

  get isHiddenMetaOnHome() {
    const route = this.router.currentRouteName || "";
    const onHome =
      route === "discovery.hot" ||
      route === "discovery.latest" ||
      route === "discovery.index";
    return onHome && !isShowcaseTopic(this.topic);
  }

  <template>
    <td
      class="recomp-card-cell {{if this.isHiddenMetaOnHome 'recomp-card-cell--hidden'}}"
      colspan="5"
    >
      <article
        class="recomp-card {{if this.coverUrl 'has-cover' 'no-cover'}}"
        data-system={{this.systemTag}}
      >
        <a
          href={{this.topic.url}}
          class="recomp-card__media"
          style={{this.cardStyle}}
          aria-label={{this.topic.title}}
        >
          {{#unless this.coverUrl}}
            <div class="recomp-card__placeholder">
              <span class="recomp-card__placeholder-label">
                {{if this.systemTag this.systemTag "RECOMP"}}
              </span>
            </div>
          {{/unless}}

          <div class="recomp-card__badges-top">
            {{#if this.systemTag}}
              <span
                class="recomp-system-pill recomp-system-pill--{{this.systemTag}}"
                data-system={{this.systemTag}}
              >
                {{this.systemTag}}
              </span>
            {{/if}}
            {{#each this.methodTags as |mtag|}}
              <span class="recomp-method-pill recomp-method-pill--{{mtag}}">
                {{mtag}}
              </span>
            {{/each}}
          </div>

          {{#if this.topic.vote_count}}
            <div class="recomp-card__vote-pill" title="Community Votes">
              ▲ {{this.topic.vote_count}}
            </div>
          {{/if}}
        </a>

        <div class="recomp-card__body">
          <div class="recomp-card__meta-top">
            {{#unless this.args.outletArgs.hideCategory}}
              {{dCategoryLink this.topic.category}}
            {{/unless}}
          </div>

          <h3 class="recomp-card__title">
            <a href={{this.topic.url}} class="title raw-topic-link">
              {{this.topic.title}}
            </a>
          </h3>

          {{#if this.excerptHtml}}
            <p class="recomp-card__excerpt">{{this.excerptHtml}}</p>
          {{/if}}

          <div class="recomp-card__tags">
            {{dDiscourseTags this.topic mode="list"}}
          </div>

          <footer class="recomp-card__footer">
            <div class="recomp-card__author">
              {{#if this.topic.creator}}
                {{dAvatar this.topic.creator imageSize="tiny"}}
                <span class="recomp-card__username">
                  {{this.topic.creator.username}}
                </span>
              {{/if}}
            </div>

            <div class="recomp-card__stats">
              {{#if this.topic.like_count}}
                <span class="recomp-stat" title="Likes">
                  ♥ {{this.topic.like_count}}
                </span>
              {{/if}}
              <span class="recomp-stat" title="Replies">
                💬 {{this.replyCount}}
              </span>
              <span class="recomp-stat recomp-stat--time">
                {{dFormatDate this.topic.bumpedAt format="tiny"}}
              </span>
            </div>
          </footer>
        </div>
      </article>
    </td>
  </template>
}

export default apiInitializer("1.14.0", (api) => {
  api.renderInOutlet("discovery-above", RecompHomepage);
  api.renderInOutlet("topic-list-item", RecompTopicCard);

  api.onPageChange((url) => {
    const hasTopicList = document.querySelector(".topic-list");
    document.body.classList.toggle("recomp-grid-active", Boolean(hasTopicList));

    const isHome =
      url === "/" ||
      url.startsWith("/hot") ||
      url.startsWith("/latest") ||
      url.startsWith("/top") ||
      url.startsWith("/new");
    document.body.classList.toggle("recomp-home-active", isHome);
  });
});
