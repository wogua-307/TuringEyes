import { rcp } from '@kit.RemoteCommunicationKit'
import { PhotoItem } from '../types'

// import { PhotoItem } from '../types'

export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH' | 'HEAD' | 'OPTIONS'

export async function getJson(url: string, baseAddress?: string): Promise<object> {
  const session = rcp.createSession(baseAddress ? { baseAddress } : undefined)
  try {
    const res = await session.get(url)
    return res.toJSON() as object
  } finally {
    session.close()
  }
}

export async function fetchJson(url: string, method: HttpMethod = 'GET', baseAddress?: string): Promise<object> {
  const session = rcp.createSession(baseAddress ? { baseAddress } : undefined)
  try {
    const req = new rcp.Request(url, method)
    const res = await session.fetch(req)
    return res.toJSON() as object
  } finally {
    session.close()
  }
}


