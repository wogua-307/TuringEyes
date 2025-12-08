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
  photographer: string,
  src: PhotoItemSrc
}

export  {
  PhotoItemSrc,
  PhotoItem
}