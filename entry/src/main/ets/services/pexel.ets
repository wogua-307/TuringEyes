import http from '@ohos.net.http'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { JSON } from '@kit.ArkTS'
import { PhotoItem } from '../types'

const SERVICE_BASE_URL: string = 'https://api.pexels.com'
let AUTH_TOKEN: string = '1YZX6PnRTsSyQtAObGVwj7aY4LZE2Qb7csIcdckzNfojUWR4Ioo6qUl0'

interface PexelsResponse {
  page: number,
  per_page: number,
  photos: PhotoItem[],
  total_results: number,
  next_page: string
}
async function httpGet(url: string): Promise<PexelsResponse> {
  const httpClient = http.createHttp()
  try {
    const response = await httpClient.request(url, {
      method: http.RequestMethod.GET,
      header: { 'Authorization': AUTH_TOKEN },
      expectDataType: http.HttpDataType.OBJECT
    })
    if (response.responseCode !== 200) {
      throw new Error('Network response was not ok')
    }
    const body = response.result as PexelsResponse
    return body
  } finally {
    httpClient.destroy()
  }
}

/**
 * 获取图片数据
 * @param page
 * @param perPage
 * @returns
 */
const  fetchPexelsCurated = async (page: number, perPage: number = 40): Promise<PexelsResponse> => {
  const result = await httpGet(`${SERVICE_BASE_URL}/v1/curated?page=${page}&per_page=${perPage}`)
  return result
}

/**
 * 搜索图片
 * @param query
 * @param page
 * @param perPage
 * @returns
 */
const  fetchPexelsSearch = async (query: string, page: number, perPage: number = 40): Promise<PexelsResponse> => {
  return await httpGet(`${SERVICE_BASE_URL}/v1/search?query=${encodeURIComponent(query)}&page=${page}&per_page=${perPage}`)
}

const fetchPexelsRandom = async (perPage: number = 40): Promise<PexelsResponse> => {
  const randomPage = Math.max(1, Math.floor(Math.random() * 20) + 1)
  return await httpGet(`${SERVICE_BASE_URL}/v1/curated?page=${randomPage}&per_page=${perPage}`)
}

export  {
  fetchPexelsCurated,
  fetchPexelsSearch,
  fetchPexelsRandom
}
