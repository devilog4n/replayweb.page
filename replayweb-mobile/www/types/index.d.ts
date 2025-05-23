import { ReplayWebApp } from "./appmain";
import { Chooser } from "./chooser";
import { ItemIndex } from "./item-index";
import { ItemInfo } from "./item-info";
import { Item } from "./item";
import { Story } from "./story";
import { GDrive } from "./gdrive";
import { Loader } from "./loader";
import { Pages } from "./pages";
import { PageEntry } from "./pageentry";
import { Replay } from "./replay";
import { Sorter } from "./sorter";
import { SWManager, serviceWorkerActivated } from "./swmanager";
import { URLResources } from "./url-resources";
import { Embed } from "./embed";
import "./coll-description";
import "./shoelace";
import rwpIcon from "~assets/icons/replaywebpage.svg";
import rwpLogoAnimated from "~assets/brand/replaywebpage-icon-color-animated.svg";
export { ReplayWebApp, Chooser, ItemIndex, ItemInfo, Item, 
/**
 * @deprecated use {@linkcode ItemIndex}
 */
ItemIndex as CollIndex, 
/**
 * @deprecated use {@linkcode ItemInfo}
 */
ItemInfo as CollInfo, 
/**
 * @deprecated use {@linkcode Item}
 */
Item as Coll, Story, GDrive, Loader, Pages, PageEntry, Replay, Sorter, URLResources, 
/**
 * @deprecated use {@linkcode ReplayWebPage}
 */
Embed, Embed as ReplayWebPage, SWManager, serviceWorkerActivated, rwpIcon, rwpLogoAnimated, };
export type { ItemType, URLResource } from "./types";
export type { EmbedReplayEvent } from "./item";
export * from "./misc";
export * from "./pageutils";
export * from "./utils/dateTimeFormatter";
//# sourceMappingURL=index.d.ts.map