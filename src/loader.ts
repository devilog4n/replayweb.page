import { LitElement, html, css, type PropertyValues, nothing } from "lit";
import { wrapCss } from "./misc";
import rwpLogo from "~assets/brand/replaywebpage-icon-color.svg";
import rwpLogoAnimated from "~assets/brand/replaywebpage-icon-color-animated.svg";

import prettyBytes from "pretty-bytes";

import { parseURLSchemeHostPath } from "./pageutils";
import { property } from "lit/decorators.js";
import type { LoadInfo } from "./item";
import { ifDefined } from "lit/directives/if-defined.js";
import { serviceWorkerActivated } from "./swmanager";

// ===========================================================================
/**
 * @fires coll-load-cancel
 */
type LoadingState =
  | "started"
  | "waiting"
  | "googledrive"
  | "errored"
  | "permission_needed";

const NO_ANIM_STATES: LoadingState[] = [
  "errored",
  "googledrive",
  "permission_needed",
];

class Loader extends LitElement {
  @property({ type: String }) sourceUrl?: string;
  @property({ type: Object }) loadInfo: LoadInfo | null = null;
  @property({ type: String }) state: LoadingState = "waiting";
  @property({ type: Number }) progress = 0;
  @property({ type: Number }) percent = 0;
  @property({ type: Number }) currentSize = 0;
  @property({ type: Number }) totalSize = 0;
  @property({ type: String }) error?: string;
  @property({ type: Number }) total = 0;
  @property({ type: String }) status?: string;
  @property({ type: String }) coll = "";
  @property({ type: String }) embed?: string;
  @property({ type: Boolean }) tryFileHandle = !!window.showOpenFilePicker;
  @property({ type: Boolean }) errorAllowRetry = false;
  @property({ type: String }) extraMsg?: string;
  @property({ type: String }) swName?: string;

  /** DOM timer ID for our ping interval, or null if none */
  private pingInterval: number | null = null;

  // eslint-disable-next-line @typescript-eslint/no-explicit-any -- requestPermission() type mismatch
  private fileHandle: any = null;
  private noWebWorker = false;
  private worker?: Worker | null;

  // Google Drive
  private _gdWait?: Promise<LoadInfo>;
  private _gdResolve!: (value: LoadInfo | PromiseLike<LoadInfo>) => void;

  firstUpdated() {
    this.initMessages();
  }

  private initMessages() {
    this.noWebWorker = Boolean(this.loadInfo?.noWebWorker);

    if (!this.noWebWorker) {
      this.worker = new Worker(this.swName!);
    } else {
      if (!navigator.serviceWorker) {
        return;
      }
      this.worker = navigator.serviceWorker as unknown as Worker;
    }

    this.worker.addEventListener("message", (event) => {
      const data = event.data as {
        msg_type: string;
        name: string;
        percent: number;
        error?: string;
        fileHandle: FileSystemHandle | null;
        currentSize?: number;
        totalSize?: number;
        extraMsg?: string;
      };

      switch (data.msg_type) {
        case "collProgress":
          if (data.name === this.coll) {
            this.percent = data.percent;
            if (data.error) {
              this.error = data.error;
              this.state = "errored";
              this.errorAllowRetry = true;
              this.fileHandle = data.fileHandle;
              if (data.error === "missing_local_file") {
                this.tryFileHandle = false;
              } else if (
                data.error === "permission_needed" &&
                data.fileHandle
              ) {
                this.state = "permission_needed";
                break;
              }
            }
            if (data.currentSize && data.totalSize) {
              this.currentSize = data.currentSize;
              this.totalSize = data.totalSize;
            }
            this.extraMsg = data.extraMsg;
          }
          break;

        case "collAdded":
          if (data.name === this.coll) {
            if (!this.total) this.total = 100;
            this.progress = this.total;
            this.percent = 100;
            this.dispatchEvent(
              new CustomEvent("coll-loaded", { detail: data })
            );

            if (!this.noWebWorker) {
              this.worker?.terminate();
            } else if (this.pingInterval !== null) {
              window.clearInterval(this.pingInterval);
              this.pingInterval = null;
            }
            this.worker = null;
          }
          break;
      }
    });
  }

  private async doLoad() {
    let sourceUrl = this.sourceUrl;
    let source: LoadInfo | null = null;

    this.percent = this.currentSize = this.totalSize = 0;

    if (this.loadInfo?.swError) {
      this.state = "errored";
      this.error = this.loadInfo.swError;
      this.errorAllowRetry = false;
      return;
    }

    try {
      const { scheme, host, path } = parseURLSchemeHostPath(sourceUrl!);

      switch (scheme) {
        case "googledrive":
          this.state = "googledrive";
          source = (await this.googledriveInit()) ?? null;
          break;

        case "s3":
          source = {
            sourceUrl,
            loadUrl: `https://${host}.s3.amazonaws.com${path}`,
            name: this.sourceUrl,
          };
          break;

        case "file":
          if (!this.loadInfo && !this.tryFileHandle) {
            this.state = "errored";
            this.error = `File URLs can not be entered directly or shared.
You can select a file to upload from the main page by clicking the 'Choose File...' button.`;
            this.errorAllowRetry = false;
            return;
          }
          source = this.loadInfo;
          break;

        case "proxy":
          sourceUrl = "proxy:" + sourceUrl!.slice("proxy://".length);
          break;
      }
    } catch (e) {
      console.error(e);
    }

    if (!source) {
      source = { sourceUrl };
    }

    this.state = "started";

    let type: string | undefined;
    let extraConfig: LoadInfo["extraConfig"] = undefined;

    if (this.loadInfo) {
      source.newFullImport = this.loadInfo.newFullImport;
      source.loadEager = this.loadInfo.loadEager;
      source.noCache = this.loadInfo.noCache;
      extraConfig = this.loadInfo.extraConfig;
      if (sourceUrl!.startsWith("proxy:") && extraConfig?.recording) {
        type = "recordingproxy";
      }
    }

    const msg = {
      msg_type: "addColl",
      name: this.coll,
      extraConfig,
      type,
      skipExisting: true,
      file: source,
    };

    await serviceWorkerActivated();

    if (this.worker) {
      if (!this.noWebWorker) {
        this.worker.postMessage(msg);
      } else {
        navigator.serviceWorker.controller!.postMessage(msg);
        this.pingInterval = window.setInterval(() => {
          navigator.serviceWorker.controller!.postMessage({ msg_type: "ping" });
        }, 15_000);
      }
    }
  }

  // eslint-disable-next-line @typescript-eslint/promise-function-async
  private googledriveInit() {
    this._gdWait = new Promise((resolve) => (this._gdResolve = resolve));
    return this._gdWait;
  }

  private onLoadReady(event: CustomEvent<LoadInfo>) {
    this._gdResolve(event.detail);
  }

  private async onCancel() {
    if (!this.worker) return;
    const msg = { msg_type: "cancelLoad", name: this.coll };

    if (!this.noWebWorker) {
      this.worker.postMessage(msg);
      await this.updateComplete;
      this.dispatchEvent(
        new CustomEvent("coll-load-cancel", { bubbles: true, composed: true })
      );
    } else if (navigator.serviceWorker.controller) {
      navigator.serviceWorker.controller.postMessage(msg);
      if (this.pingInterval !== null) {
        window.clearInterval(this.pingInterval);
        this.pingInterval = null;
      }
    }
  }

  updated(changed: PropertyValues<this>) {
    if (
      (this.sourceUrl && changed.has("sourceUrl")) ||
      changed.has("tryFileHandle")
    ) {
      this.doLoad();
    }
  }

  static get styles() {
    return wrapCss(css`
      :host {
        height: 100%;
        display: flex;
      }
      .progress-div {
        position: relative;
        width: 400px !important;
      }
      .progress-label {
        position: absolute;
        top: 0;
        left: 50%;
        transform: translateX(-50%);
        font-size: calc(1.5rem / 1.5);
        line-height: 1.5rem;
      }
      .loaded-prog {
        margin-bottom: 1em;
      }
      .error {
        white-space: pre-wrap;
        margin-bottom: 2em;
      }
      section.container {
        margin: auto;
      }
      .extra-msg {
        font-size: 0.8rem;
      }
    `);
  }

  render() {
    return html`
      <section class="container">
        <div class="is-justify-content-center is-flex">
          <fa-icon
            size="5rem"
            style="margin-bottom: 1rem;"
            .svg=${NO_ANIM_STATES.includes(this.state)
              ? rwpLogo
              : rwpLogoAnimated}
            aria-label="ReplayWeb.page Logo"
            role="img"
          ></fa-icon>
        </div>
        ${!this.embed
          ? html`
              <div class="level">
                <p class="level-item">Loading <b>${this.sourceUrl}</b>…</p>
              </div>
            `
          : ""}
        <div class="level">
          <div class="level-item has-text-centered">
            ${this.renderContent()}
          </div>
        </div>
      </section>
    `;
  }

  private renderContent() {
    switch (this.state) {
      case "googledrive":
        return html`<wr-gdrive
          .sourceUrl=${this.sourceUrl!}
          @load-ready=${this.onLoadReady}
        ></wr-gdrive>`;
      case "started":
        return html`
          <div class="progress-div">
            ${!this.currentSize ? nothing : this.renderProgressBar()}
            ${!this.embed
              ? html`
                  <button @click=${this.onCancel} class="button is-danger">
                    Cancel
                  </button>
                `
              : ""}
          </div>
        `;
      case "errored":
        return html`
          <div class="has-text-left">
            <div class="error has-text-danger">${this.error}</div>
            <div>
              ${this.errorAllowRetry
                ? html`
                    <a
                      class="button is-warning"
                      @click=${() => window.parent.location.reload()}
                      >Try Again</a
                    >
                  `
                : ""}
              ${this.embed
                ? nothing
                : html`<a href="/" class="button is-warning">Back</a>`}
            </div>
          </div>
        `;
      case "permission_needed":
        return html`
          <div class="has-text-left">
            <div>
              Permission is needed to reload the archive file. (Click
              <i>Cancel</i> to cancel loading this archive.)
            </div>
            <button @click=${this.onAskPermission} class="button is-primary">
              Show Permission
            </button>
            <a href="/" class="button is-danger">Cancel</a>
          </div>
        `;
      default:
        return nothing;
    }
  }

  private renderProgressBar() {
    const pct =
      this.currentSize && this.totalSize
        ? Math.max(this.percent, (this.currentSize / this.totalSize) * 100)
        : this.percent;
    const display = pct ? Math.max(pct, 1) : undefined;

    return html`
      <progress
        id="progress"
        class="progress is-primary is-large"
        value=${ifDefined(display)}
        max="100"
      ></progress>
      ${display
        ? html`<label class="progress-label" for="progress"
            >${display}%</label
          >`
        : nothing}
      ${this.currentSize && this.totalSize
        ? html`
            <div class="loaded-prog">
              Loaded <b>${prettyBytes(this.currentSize)}</b> of
              <b>${prettyBytes(this.totalSize)}</b>
              ${this.extraMsg
                ? html`<p class="extra-msg">(${this.extraMsg})</p>`
                : ""}
            </div>
          `
        : nothing}
    `;
  }

  private async onAskPermission() {
    const result = await this.fileHandle?.requestPermission({ mode: "read" });
    if (result === "granted") {
      this.doLoad();
    }
  }
}

customElements.define("wr-loader", Loader);
export { Loader };
