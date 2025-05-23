import rwpLogo from "~assets/brand/replaywebpage-icon-color.svg";
import webrecorderLockupColor from "~assets/brand/webrecorder-lockup-color.svg";
import btAngleDoubleDown from "~assets/icons/chevron-double-down.svg";
import btAngleDoubleUp from "~assets/icons/chevron-double-up.svg";
import fabGithub from "@fortawesome/fontawesome-free/svgs/brands/github.svg";
import fasDownload from "@fortawesome/fontawesome-free/svgs/solid/download.svg";

import { clickOnSpacebarPress } from "./misc";

import { LitElement, html, css, nothing } from "lit";
import { tsToDate } from "./pageutils";
import prettyBytes from "pretty-bytes";
import { property } from "lit/decorators.js";
import type { ItemType } from "./types";
import { dateTimeFormatter } from "./utils/dateTimeFormatter";

// ===========================================================================
export class RWPEmbedReceipt extends LitElement {
  @property({ type: Object }) collInfo:
    | ItemType
    | null
    | Record<string, never> = null;
  @property({ type: String }) ts: string | null = null;
  @property({ type: String }) url: string | null = null;

  @property({ type: Boolean }) active = false;

  // @ts-expect-error - TS2611 - 'renderRoot' is defined as a property in class 'LitElement', but is overridden here in 'RWPEmbedReceipt' as an accessor.
  get renderRoot() {
    return this;
  }

  static get embedStyles() {
    return css`
      rwp-embed-receipt {
        display: flex;
        flex-direction: column;
      }

      .icon {
        vertical-align: text-top;
      }

      #embed-dropdown {
        max-height: calc(100vh - 50px);
        padding-top: 0;
        margin-top: -0.5rem;
        display: block;
        z-index: 1;
        pointer-events: none;
        transition: all 0.3s linear;
        transform-origin: left top;
        transform: scaleY(0);
        transition: all 300ms cubic-bezier(0.15, 0, 0.1, 1);
        filter: drop-shadow(0px 8px 4px rgba(0, 0, 0, 0.15));
      }

      .dropdown.is-active #embed-dropdown {
        transform: scaleY(1);
      }

      .embed-info-container {
        width: 100%;
        display: flex !important;
        justify-content: center;
      }

      button.embed-info {
        padding: 0;
        background-color: white;
        justify-content: space-between;
        max-width: 40rem;
        width: calc(100% - 1rem);
        height: 42px;
        border-color: #d1d5da;
        border-width: 1px;
        border-style: solid;
        border-radius: 999px;
        display: flex;
        align-items: center;
        text-overflow: ellipsis;
        filter: drop-shadow(0px 1px 2px rgba(0, 0, 0, 0.15));
        transition-duration: 50ms;
        transition-timing-function: ease-out;
        cursor: pointer;
        z-index: 2;
      }

      button.embed-info:active {
        color: initial;
      }

      button.embed-info:hover {
        filter: drop-shadow(0px 2px 4px rgba(0, 0, 0, 0.2));
        transform: scale(1.01);
      }

      button.embed-info:hover:active {
        transform: translateY(0.25rem);
      }

      .embed-info-buttontext {
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        flex-grow: 1;
        text-align: start;
        font-size: 13px;
      }

      .embed-info-drop {
        font-size: 14px;
        padding: 1rem;
        padding-top: 2rem;
        max-width: 38rem;
        max-height: 42rem;
        width: calc(100% - 2rem);
        border-top-right-radius: 0px;
        border-top-left-radius: 0px;
        pointer-events: auto;
        overflow-y: auto;
      }

      .embed-info-drop > p {
        font-size: 14px;
        color: black;
      }

      .embed-info-drop > h2 {
        margin-bottom: 0.25rem;
        font-size: 16px;
        font-weight: bold;
        text-transform: none;
        letter-spacing: 0;
        color: #24292e;
      }

      .embed-info-drop-statscontainer > h3 {
        font-size: 12px;
        color: #394146;
      }

      .embed-info-drop-statscontainer > p {
        font-size: 14px;
        color: black;
      }

      .embed-info-drop a {
        word-break: break-all;
      }

      .embed-info-drop .show-hash {
        word-break: break-all;
        font-family: monospace;
      }

      .embed-info-drop .show-key {
        text-overflow: ellipsis;
        overflow: hidden;
        whitespace: nowrap;
        font-family: monospace;
      }

      .embed-logo {
        margin: 0.5rem;
        line-height: 0.5rem;
      }
    `;
  }

  render() {
    const {
      numValid = 0,
      numInvalid = 0,
      domain,
      certFingerprint,
      datapackageHash,
      publicKey,
      software,
    } = this.collInfo?.verify ?? {};

    const sourceUrl = this.collInfo?.sourceUrl;

    const certFingerprintUrl = certFingerprint
      ? `https://crt.sh/?q=${certFingerprint}`
      : "";

    const dateStr = this.ts
      ? dateTimeFormatter.format(tsToDate(this.ts) as Date)
      : "";

    return html`
      <div class="dropdown mb-4 ${this.active ? "is-active" : ""}">
        <div class="dropdown-trigger embed-info-container">
          <button
            class="embed-info is-small is-rounded mt-4"
            aria-haspopup="true"
            aria-controls="embed-dropdown"
            @click="${this.onEmbedDrop}"
          >
            <fa-icon
              class="embed-logo"
              size="1.5rem"
              aria-hidden="true"
              .svg=${rwpLogo}
            ></fa-icon>
            <span class="embed-info-buttontext">
              This embed is part of a web archive. Click here to learn more.
            </span>
            <span class="icon is-small mr-4 ml-2">
              <fa-icon
                title="Toggle"
                .svg="${this.active ? btAngleDoubleUp : btAngleDoubleDown}"
                aria-hidden="true"
              ></fa-icon>
            </span>
          </button>
        </div>
        <div
          class="dropdown-menu embed-info-container"
          id="embed-dropdown"
          role="menu"
        >
          <div class="dropdown-content embed-info-drop">
            <p class="mb-4">
              Even if the original page goes offline or is changed, the content
              below will remain unchanged as it is loaded from a web archive.
            </p>
            <hr class="dropdown-divider" />
            <h2 class="mt-4">Get A Copy!</h2>
            <p class="mt-2">
              After downloading, this web archive can be loaded and viewed
              directly in your browser via
              <a
                style="white-space: nowrap;"
                target="_blank"
                href="https://replayweb.page"
                >ReplayWeb.page</a
              >.
            </p>
            ${sourceUrl
              ? html`
                  <a
                    href="${sourceUrl}"
                    class="button is-primary mt-4"
                    @keyup="${clickOnSpacebarPress}"
                  >
                    <span class="icon is-small">
                      <fa-icon
                        size="1.0em"
                        aria-hidden="true"
                        .svg="${fasDownload}"
                      ></fa-icon>
                    </span>
                    <span>Download Archive</span>
                  </a>
                  <hr class="dropdown-divider mt-4" />
                `
              : nothing}
            <h2 class="mt-4">Technical Information</h2>
            <div class="embed-info-drop-statscontainer mb-4">
              ${this.url
                ? html`
                    <h3>Original URL:</h3>
                    <p>
                      <a target="_blank" href="${this.url}">${this.url}</a>
                    </p>
                  `
                : nothing}
              <h3 class="mt-2">Archived On:</h3>
              <p>${dateStr}</p>
              ${domain
                ? html`
                    <h3 class="mt-2">Observed By:</h3>
                    <p>${domain}</p>
                    ${certFingerprintUrl
                      ? html` <p>
                          <a target="_blank" href="${certFingerprintUrl}"
                            >View Certificate</a
                          >
                        </p>`
                      : ""}
                  `
                : software
                ? html` <h3 class="mt-2">Created With:</h3>
                    <p>${software}</p>`
                : ""}
              ${!domain && publicKey
                ? html` <h3 class="mt-2">Observer Public Key:</h3>
                    <p class="show-key">${publicKey}</p>`
                : ""}
              <h3 class="mt-2">Validation:</h3>
              ${numValid > 0 || numInvalid > 0
                ? html` <p>
                    ${numValid} hashes
                    verified${numInvalid ? html`, ${numInvalid} invalid` : ""}
                  </p>`
                : html` <p>Not Available</p> `}
              <h3 class="mt-2">Package Hash:</h3>
              <p class="show-hash">${datapackageHash}</p>
              ${this.collInfo?.size != null
                ? html`
                    <h3 class="mt-2">Size</h3>
                    <p>${prettyBytes(Number(this.collInfo.size || 0))}</p>
                  `
                : nothing}
            </div>
            ${sourceUrl ? html`` : ""}
            <div
              class="is-size-7 is-flex is-justify-content-space-between is-align-items-center"
              style="margin-top: 40px"
            >
              <div>
                <a
                  target="_blank"
                  href="https://webrecorder.net/"
                  aria-label="Webrecorder"
                >
                  <fa-icon
                    size=""
                    height="1rem"
                    width="10rem"
                    .svg=${webrecorderLockupColor}
                    aria-label=""
                    aria-hidden="true"
                    style="color:#001219;"
                  ></fa-icon>
                </a>
              </div>
              <span>
                <a
                  class="has-text-black"
                  target="_blank"
                  href="https://github.com/webrecorder/replayweb.page"
                  aria-label="ReplayWeb.page source code"
                  >Source Code
                  <fa-icon
                    class="menu-logo ml-1"
                    size="1rem"
                    aria-hidden="true"
                    .svg=${fabGithub}
                  ></fa-icon>
                </a>
              </span>
            </div>
          </div>
        </div>
      </div>
    `;
  }

  // @ts-expect-error [// TODO: Fix this the next time the file is edited.] - TS7006 - Parameter 'event' implicitly has an 'any' type.
  onEmbedDrop(event) {
    event.stopPropagation();
    this.active = !this.active;
  }
}

customElements.define("rwp-embed-receipt", RWPEmbedReceipt);
