import { fetchPexelsCurated, fetchPexelsSearch, fetchPexelsRandom } from '../services/pexel'
import { PhotoItem } from '../types'
import { PexelDataSource } from './source/PexelDataSource'
import { hilog } from '@kit.PerformanceAnalysisKit'
import preferences from '@ohos.data.preferences'
import router from '@ohos.router'

@Component
export struct HomePage {
  @State private loading: boolean = false
  @State private page: number = 1
  @State private query: string = ''
  @State private activeTag: string = '精选'
  @State private selectedTag: string = '精选'
  @State private tags: string[] = ['精选', '圣诞节','星空', '大海', '动物', '卡通', '汽车', '科技', '宇宙', '自然', '建筑', '人物']
  @State private photos: PhotoItem[] = []
  @StorageLink('app_favorite_ids') favoriteIds: number[] = []
  @State private previewItem: PhotoItem | undefined = undefined
  @State private initialized: boolean = false
  private photoDataSource: PexelDataSource = new PexelDataSource(this.photos)
  private scroller: Scroller = new Scroller()

  aboutToAppear() {
    if (!this.initialized) {
      this.initFavorites()
      this.loadCurated(true)
      this.initialized = true
    }
  }

  onPageShow() {
    // favorites are synced via AppStorage, no need to reload from prefs
    this.photoDataSource.notifyDataReload()
  }

  private async initFavorites() {
    // Load only if empty or force reload? 
    // Ideally we assume AppStorage might be empty on fresh start.
    // If it's already set by another page/session, we might overwrite?
    // But Home is usually the first page.
    const ctx = getContext(this)
    try {
      const prefs = await preferences.getPreferences(ctx, 'photo_favorites')
      const stored = await prefs.get('favorites', '[]') as string
      // Only set if we really want to load initial state.
      // Since AppStorage is global, loading it here is fine.
      this.favoriteIds = JSON.parse(stored)
    } catch (e) {
      hilog.error(0x0000, 'Home', 'initFavorites error %{public}s', JSON.stringify(e))
      // Handle preference corruption (error 15500000)
      try {
        await preferences.deletePreferences(ctx, 'photo_favorites')
        this.favoriteIds = []
      } catch (e2) {
        hilog.error(0x0000, 'Home', 'reset preferences error %{public}s', JSON.stringify(e2))
      }
    }
  }

  private async persistFavorites() {
    const ctx = getContext(this)
    try {
      const prefs = await preferences.getPreferences(ctx, 'photo_favorites')
      await prefs.put('favorites', JSON.stringify(this.favoriteIds))
      await prefs.flush()
    } catch (e) {
      hilog.error(0x0000, 'Home', 'persistFavorites error %{public}s', JSON.stringify(e))
    }
  }

  private async loadCurated(reset: boolean = false) {
    this.loading = true
    try {
      const res = reset ? await fetchPexelsRandom() : await fetchPexelsCurated(this.page)
      this.page = res.page
      this.photos = reset ? res.photos : [...this.photos, ...res.photos]
      this.photoDataSource.updateData(this.photos)
      this.activeTag = '精选'
      this.selectedTag = '精选'
    } catch (e) {
      hilog.error(0x0000, 'Home', 'loadCurated error %{public}s', JSON.stringify(e))
    } finally {
      this.loading = false
    }
  }

  private async doSearch(query: string, reset: boolean = true) {
    this.loading = true
    try {
      const res = await fetchPexelsSearch(query, reset ? 1 : this.page)
      this.page = res.page
      this.photos = reset ? res.photos : [...this.photos, ...res.photos]
      this.photoDataSource.updateData(this.photos)
    } catch (e) {
      hilog.error(0x0000, 'Home', 'doSearch error %{public}s', JSON.stringify(e))
    } finally {
      this.loading = false
    }
  }

  private onTagClick(tag: string) {
    if (this.loading) {
      return
    }
    this.activeTag = tag
    this.selectedTag = tag
    if (tag === '精选') {
      this.loadCurated(true)
    } else {
      this.query = tag
      this.doSearch(this.normalizeQuery(tag), true)
    }
  }

  private onSearchSubmit() {
    const q = this.query.trim()
    if (!q) {
      this.selectedTag = '精选'
      this.loadCurated(true)
      return
    }
    if (this.tags.indexOf(q) !== -1) {
      this.activeTag = q
      this.selectedTag = q
    } else {
      this.activeTag = ''
      this.selectedTag = ''
    }
    this.doSearch(this.normalizeQuery(q), true)
  }

  private isFavorite(id: number): boolean {
    return this.favoriteIds.indexOf(id) !== -1
  }

  private toggleFavorite(item: PhotoItem): void {
    const idx = this.favoriteIds.indexOf(item.id)
    if (idx === -1) {
      this.favoriteIds = [...this.favoriteIds, item.id]
    } else {
      const next = [...this.favoriteIds]
      next.splice(idx, 1)
      this.favoriteIds = next
    }
    this.persistFavorites()
  }

  private openPreview(item: PhotoItem): void {
    router.pushUrl({
      url: 'pages/Preview',
      params: { item: JSON.stringify(item), favs: JSON.stringify(this.favoriteIds) }
    }, router.RouterMode.Standard)
  }

  @Builder
  itemFoot() {
    LoadingProgress()
      .width('100%')
      .height(48)
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        Row() {
          Row() {
            Text('L')
              .width(32)
              .height(32)
              .borderRadius(16)
              .backgroundColor('#16a34a')
              .fontColor('#fff')
              .fontSize(20)
              .textAlign(TextAlign.Center)
          }
          .width(40)

          Text($r('app.string.app_name'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .margin({ left: 8 })
        }
        .width('100%')
        .padding({ top: 24, left: 20, right: 20 })

        Row() {
          TextInput({ placeholder: '输入关键词', text: this.query })
            .height(48)
            .borderRadius(12)
            .backgroundColor('#f4f4f6')
            .padding({ left: 16 })
            .layoutWeight(1)
            .onChange((v: string) => this.query = v)
          Button('搜索')
            .type(ButtonType.Capsule)
            .margin({ left: 12 })
            .height(48)
            .onClick(() => this.onSearchSubmit())
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 8 })

        Scroll() {
          Row() {
            ForEach(this.tags, (tag: string) => {
              this.TagChip(tag)
            })
          }
          .padding({ left: 20, right: 20 })
          .height(55)
          .margin({ top: 10, bottom: 10 })
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Start)
        }.scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)

        WaterFlow({ footer: this.itemFoot, scroller: this.scroller }) {
          LazyForEach(this.photoDataSource, (item: PhotoItem) => {
            FlowItem() {
              PhotoCardItem({
                item: item,
                favoriteIds: this.favoriteIds,
                toggleFavorite: (it: PhotoItem): void => this.toggleFavorite(it),
                openPreview: (it: PhotoItem): void => this.openPreview(it)
              })
            }
          }, (item: PhotoItem) => item.id.toString())
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(12)
        .rowsGap(12)
        .padding({ left: 20, right: 20, bottom: 80 })
        .scrollBar(BarState.Off)
        .onReachEnd(() => this.loadMore())

        // 瀑布流替代 List 渲染

        if (this.loading) {
          LoadingProgress()
            .width('100%')
            .height(48)
        }
      }
      .width('100%')
      .height('100%')

      Button('↑')
        .type(ButtonType.Circle)
        .width(45)
        .height(45)
        .fontSize(18)
        .backgroundColor('#f5f5f5')
        .fontColor('#000')
        .margin({ right: 20, bottom: 28 })
        .onClick(() => {
          this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: { duration: 300 } })
        })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TagChip(label: string) {
    Button(label)
      .type(ButtonType.Capsule)
      .stateEffect(true)
      .enabled(!this.loading)
      .backgroundColor((label === this.selectedTag) ? '#000' : '#eee')
      .fontColor((label === this.selectedTag) ? '#fff' : '#333')
      .margin({ right: 8 })
      .onClick(() => {
        this.onTagClick(label)
      })
  }

  // 使用 WaterFlow 渲染，无需行分组

  private async loadMore() {
    if (this.photos.length >= 320) return
    const nextPage = this.page + 1
    this.loading = true
    try {
      if (this.activeTag === '精选') {
        const res = await fetchPexelsCurated(nextPage)
        this.page = res.page
        this.photos = [...this.photos, ...res.photos]
        this.photoDataSource.updateData(this.photos)
      } else {
        const q = this.normalizeQuery(this.activeTag || this.query || 'Curated')
        const res = await fetchPexelsSearch(q, nextPage)
        this.page = res.page
        this.photos = [...this.photos, ...res.photos]
        this.photoDataSource.updateData(this.photos)
      }
    } catch (e) {
      hilog.error(0x0000, 'Home', 'loadMore error %{public}s', JSON.stringify(e))
    } finally {
      this.loading = false
    }
  }

  private tagQueryMap: Record<string, string> = {
    '圣诞节': 'christmas',
    '星空': 'stars',
    '大海': 'ocean',
    '科技': 'technology',
    '宇宙': 'space',
    '动物': 'animals',
    '自然': 'nature',
    '建筑': 'architecture',
    '人物': 'people'
  }

  private normalizeQuery(q: string): string {
    return this.tagQueryMap[q] || q
  }
}

@Component
export struct PhotoCardItem {
  item: PhotoItem = {
    id: 0,
    width: 0,
    height: 0,
    url: '',
    photographer: '',
    photographer_url: '',
    photographer_id: '',
    alt: '',
    avg_color: '#eeeeee',
    src: {
      original: '',
      large: '',
      medium: '',
      small: ''
    }
  }
  @Prop favoriteIds: number[] = []
  toggleFavorite: (item: PhotoItem) => void = (item: PhotoItem) => {
  }
  openPreview: (item: PhotoItem) => void = (item: PhotoItem) => {
  }
  @State private imgLoading: boolean = true

  build() {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        Column() {
          Blank()
            .width('100%')
            .height('100%')
        }

        Image(this.item.src.large)
          .objectFit(ImageFit.Cover)
          .width('100%')
          .height('100%')
          .onComplete(() => {
            this.imgLoading = false
          })
          .onClick(() => this.openPreview(this.item))

        if (this.imgLoading) {
          Row() {
            LoadingProgress()
              .width(32)
              .height(32)
          }
          .align(Alignment.Center)
          .justifyContent(FlexAlign.Center)
          .width('100%')
          .height('100%')
        }

        Button() {
          Image(this.isFav(this.item.id) ? $r('app.media.collection') : $r('app.media.collection_no'))
            .width(20)
            .height(20)
        }
          .type(ButtonType.Circle)
          .width(32)
          .height(32)
          .backgroundColor('#ffffff')
          .margin({ right: 12, top: 12 })
          .onClick(() => this.toggleFavorite(this.item))
      }
      .margin({ bottom: 0 })
      .width('100%')
      .aspectRatio(this.getAspect())
      .borderRadius(16)
      .clip(true)
      .backgroundColor(this.item.avg_color || '#eee')
    }
  }

  private getAspect(): number {
    const w = this.item.width || 0
    const h = this.item.height || 0
    if (w > 0 && h > 0) {
      return w / h
    }
    return 3 / 4
  }

  private isFav(id: number): boolean {
    return this.favoriteIds.indexOf(id) !== -1
  }
}
