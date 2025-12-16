import preferences from '@ohos.data.preferences'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { PhotoItem } from '../types'

export class FavoriteManager {
  private static readonly PREF_NAME = 'photo_favorites_db'
  private static readonly KEY_ITEMS = 'items'

  static async add(context: common.UIAbilityContext, item: PhotoItem): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(context, FavoriteManager.PREF_NAME)
      const json = await prefs.get(FavoriteManager.KEY_ITEMS, '[]') as string
      let items = JSON.parse(json) as PhotoItem[]
      
      // Check if exists
      if (!items.find(i => i.id === item.id)) {
        items.unshift(item) // Add to top
        await prefs.put(FavoriteManager.KEY_ITEMS, JSON.stringify(items))
        await prefs.flush()
      }
    } catch (e) {
      hilog.error(0x0000, 'FavMgr', 'add error %{public}s', JSON.stringify(e))
    }
  }

  static async remove(context: common.UIAbilityContext, id: number): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(context, FavoriteManager.PREF_NAME)
      const json = await prefs.get(FavoriteManager.KEY_ITEMS, '[]') as string
      let items = JSON.parse(json) as PhotoItem[]
      
      const newItems = items.filter(i => i.id !== id)
      if (newItems.length !== items.length) {
        await prefs.put(FavoriteManager.KEY_ITEMS, JSON.stringify(newItems))
        await prefs.flush()
      }
    } catch (e) {
      hilog.error(0x0000, 'FavMgr', 'remove error %{public}s', JSON.stringify(e))
    }
  }

  static async getAll(context: common.UIAbilityContext): Promise<PhotoItem[]> {
    try {
      const prefs = await preferences.getPreferences(context, FavoriteManager.PREF_NAME)
      const json = await prefs.get(FavoriteManager.KEY_ITEMS, '[]') as string
      return JSON.parse(json) as PhotoItem[]
    } catch (e) {
      hilog.error(0x0000, 'FavMgr', 'getAll error %{public}s', JSON.stringify(e))
      return []
    }
  }
}
