interface PhotoItemSrc {
  original: string,
  large: string,
  medium: string,
  small: string,
  portrait?: string,
  landscape?: string,
  tiny?: string,
}

interface PhotoItem {
  id: number,
  width: number,
  height: number,
  url: string,
  photographer: string,
  photographer_url: string,
  photographer_id: string,
  alt?: string,
  avg_color: string,
  src: PhotoItemSrc
}

export  {
  PhotoItemSrc,
  PhotoItem
}