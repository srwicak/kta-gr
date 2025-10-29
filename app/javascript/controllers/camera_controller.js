import { Controller } from "@hotwired/stimulus"

// Camera capture with guide box and cropping for selfie (portrait) and KTP (landscape)
// Usage: attach data-controller="camera" on a wrapper and wire file inputs via targets.
export default class extends Controller {
  static targets = [
    "wrap", "video", "guide", "canvas", "modal", "modeLabel",
    "selfieInput", "selfiePreview",
    "ktpInput", "ktpPreview"
  ]

  connect() {
    this.mode = "selfie" // default
    this.stream = null
    this.boundResize = this.layoutGuide.bind(this)
    this.workCanvas = document.createElement("canvas") // offscreen for detection
  }

  // UI actions
  openSelfie() { this.openCamera("selfie") }
  openKtp() { this.openCamera("ktp") }

  async openCamera(mode) {
    // Determine which input/preview to bind to
    this.mode = mode
    this.currentInputTarget = mode === "selfie" ? this.selfieInputTarget : this.ktpInputTarget
    this.currentPreviewTarget = mode === "selfie" ? this.selfiePreviewTarget : this.ktpPreviewTarget

    // Show modal first so layout sizes are known
    this.modalTarget.classList.remove("hidden")
    this.modeLabelTarget.textContent = mode === "selfie" ? "Mode: Selfie (Portrait)" : "Mode: KTP (Landscape)"

    try {
      // Feature detect and HTTPS requirement
      const supported = !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia)
      const secureOK = window.isSecureContext || ["localhost", "127.0.0.1"].includes(location.hostname)
      if (!supported || !secureOK) {
        // Fallback: close modal and open file input
        this.closeModal()
        const reason = !supported ? "Perangkat/Browser tidak mendukung kamera" : "Kamera butuh HTTPS (gunakan https/ngrok)"
        alert("Tidak bisa akses kamera: " + reason + "\nSilakan pilih file foto dari galeri.")
        // trigger file picker
        this.currentInputTarget?.click()
        return
      }

      // Start stream with best-effort selection of front/back camera
      await this.startStreamForMode(mode)
      this.videoTarget.srcObject = this.stream
      this.videoTarget.playsInline = true
      this.videoTarget.autoplay = true
      // mirror preview for selfie; robust across Tailwind availability
      const mirror = mode === "selfie"
      this.videoTarget.classList.toggle("-scale-x-100", mirror)
      this.videoTarget.style.transform = mirror ? "scaleX(-1)" : ""
      await this.videoTarget.play()
      // Layout guide after video has metadata
      this.layoutGuide()
      window.addEventListener("resize", this.boundResize)
    } catch (e) {
      this.closeModal()
      alert("Tidak bisa akses kamera: " + (e?.message || e) + "\nSilakan gunakan upload file sebagai alternatif.")
      this.currentInputTarget?.click()
    }
  }

  async startStreamForMode(mode) {
    this.stopStream()
    const wantFront = mode === "selfie"
    const fm = wantFront ? "user" : "environment"

    // Try a cascade of constraints: exact -> ideal -> fallback
    const attempts = [
      { video: { facingMode: { exact: fm } }, audio: false },
      { video: { facingMode: { ideal: fm } }, audio: false },
      { video: true, audio: false },
    ]

    let lastErr
    for (const c of attempts) {
      try {
        this.stream = await navigator.mediaDevices.getUserMedia(c)
        break
      } catch (err) {
        lastErr = err
        this.stream = null
      }
    }
    if (!this.stream) throw lastErr || new Error("Gagal membuka kamera")

    // After permission granted, labels are available; refine with enumerateDevices
    try {
      if (!navigator.mediaDevices.enumerateDevices) return
      const devices = (await navigator.mediaDevices.enumerateDevices()).filter(d => d.kind === "videoinput")
      if (!devices.length) return

      const curTrack = this.stream.getVideoTracks()[0]
      const cur = curTrack.getSettings?.() || {}
      const isFrontLabel = (s) => /front|user|depan/i.test(s)
      const isBackLabel = (s) => /back|environment|rear|belakang/i.test(s)

      let preferred
      if (wantFront) {
        preferred = devices.find(d => isFrontLabel(d.label)) || devices.find(d => !isBackLabel(d.label))
      } else {
        preferred = devices.find(d => isBackLabel(d.label)) || devices.find(d => !isFrontLabel(d.label))
      }

      if (preferred && preferred.deviceId && preferred.deviceId !== cur.deviceId) {
        // Switch to the preferred device
        this.stopStream()
        this.stream = await navigator.mediaDevices.getUserMedia({ video: { deviceId: { exact: preferred.deviceId } }, audio: false })
      }
    } catch (_) {
      // ignore refinement failures
    }
  }

  // Compute and set guide box size based on container and mode aspect ratio
  layoutGuide() {
    const wrap = this.wrapTarget
    const guide = this.guideTarget
    if (!wrap || !guide) return

    // container size
    const cw = wrap.clientWidth
    const ch = wrap.clientHeight
    if (!cw || !ch) return

    // aspect ratios
    const AR = { selfie: 3/4, ktp: 85.6/53.98 } // width/height
    const WIDTH_PCT = { selfie: 0.7, ktp: 0.85 }

    let gw = cw * WIDTH_PCT[this.mode]
    let gh = gw / AR[this.mode]
    if (gh > ch * 0.85) { gh = ch * 0.85; gw = gh * AR[this.mode] }
    guide.style.width = `${gw}px`
    guide.style.height = `${gh}px`
  }

  // Capture current frame and crop to guide box, then fill input and preview
  async capture() {
    const video = this.videoTarget
    const wrap = this.wrapTarget
    const guide = this.guideTarget
    const canvas = this.canvasTarget
    const vw = video.videoWidth, vh = video.videoHeight
    if (!vw || !vh) return

    // cover fit scaling
    const cw = wrap.clientWidth, ch = wrap.clientHeight
    const scale = Math.max(cw / vw, ch / vh)
    const rw = vw * scale, rh = vh * scale
    const ox = (rw - cw) / 2, oy = (rh - ch) / 2

    const wrapRect = wrap.getBoundingClientRect()
    const guideRect = guide.getBoundingClientRect()
    const x = guideRect.left - wrapRect.left
    const y = guideRect.top - wrapRect.top
    const w = guideRect.width
    const h = guideRect.height

    // account for mirror in selfie preview
    let xVideo
    const mirrored = this.videoTarget.classList.contains("-scale-x-100")
    if (mirrored) {
      xVideo = (rw - (x + ox) - w) / scale
    } else {
      xVideo = (x + ox) / scale
    }
    const yVideo = (y + oy) / scale
    const wVideo = w / scale
    const hVideo = h / scale

    // Lightweight selfie validation: if FaceDetector available, require exactly one face inside guide
    if (this.mode === "selfie") {
      const ok = await this.selfieQualityCheck({ cw, ch, rw, rh, scale, mirrored })
      if (!ok) {
        alert("Selfie kurang jelas: pastikan 1 wajah terlihat di dalam kotak panduan.")
        return
      }
    }

    // bound max size to reduce file size
    const maxSide = 1400
    const outScale = Math.min(1, maxSide / Math.max(wVideo, hVideo))
    canvas.width = Math.round(wVideo * outScale)
    canvas.height = Math.round(hVideo * outScale)

    const ctx = canvas.getContext("2d")
    ctx.save()
    // For mirrored preview, the underlying pixel data is not mirrored; we already corrected xVideo
    ctx.drawImage(video, xVideo, yVideo, wVideo, hVideo, 0, 0, canvas.width, canvas.height)
    ctx.restore()

    canvas.toBlob(async (blob) => {
      if (!blob) return
      // Convert Blob to File and assign to input
      const filename = `capture-${this.mode}.jpg`
      const file = new File([blob], filename, { type: "image/jpeg" })
      const dt = new DataTransfer()
      dt.items.add(file)
      this.currentInputTarget.files = dt.files
      // Show preview
      this.currentPreviewTarget.src = URL.createObjectURL(blob)
      this.currentPreviewTarget.classList.remove("hidden")
      // Close camera
      this.closeModal()
    }, "image/jpeg", 0.85)
  }

  async selfieQualityCheck({ cw, ch, rw, rh, scale, mirrored }) {
    try {
      if (!("FaceDetector" in window)) return true // not supported: skip check
      const fd = new window.FaceDetector({ fastMode: true, maxDetectedFaces: 2 })

      // Draw current frame to offscreen canvas in the same cover layout as preview
      const c = this.workCanvas
      c.width = cw; c.height = ch
      const ctx = c.getContext("2d")
      ctx.save()
      if (mirrored) {
        ctx.translate(cw, 0)
        ctx.scale(-1, 1)
      }
      const dx = (cw - rw) / 2
      const dy = (ch - rh) / 2
      ctx.drawImage(this.videoTarget, dx, dy, rw, rh)
      ctx.restore()

      const faces = await fd.detect(c)
      if (!faces || faces.length !== 1) return false

      // Check face center is inside guide and size is reasonable
      const face = faces[0].boundingBox
      const wrapRect = this.wrapTarget.getBoundingClientRect()
      const guideRect = this.guideTarget.getBoundingClientRect()
      const gx = guideRect.left - wrapRect.left
      const gy = guideRect.top - wrapRect.top
      const gw = guideRect.width
      const gh = guideRect.height

      const fx = face.x + face.width / 2
      const fy = face.y + face.height / 2
      const centerInside = (fx >= gx && fx <= gx + gw && fy >= gy && fy <= gy + gh)
      const sizeOk = face.height >= gh * 0.35 && face.height <= gh * 0.95
      return centerInside && sizeOk
    } catch (_) {
      // If detection fails for any reason, don't block the user
      return true
    }
  }

  closeModal() {
    this.stopStream()
    window.removeEventListener("resize", this.boundResize)
    this.modalTarget.classList.add("hidden")
  }

  stopStream() {
    if (this.stream) {
      this.stream.getTracks().forEach(t => t.stop())
      this.stream = null
    }
    if (this.videoTarget) this.videoTarget.srcObject = null
  }

  disconnect() {
    this.stopStream()
    window.removeEventListener("resize", this.boundResize)
  }
}
