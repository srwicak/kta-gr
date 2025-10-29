import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static targets = ["nik", "prov", "reg", "dis", "birth", "gender", "domProv", "domReg", "domDis", "domVil"]

  connect() {
    this.onInput()
  }

  onInput() {
    const nik = this.nikTarget?.value || ""
    const digits = nik.replace(/\D/g, "")
    if (digits.length < 6) return
    fetch(`/api/nik_info?nik=${encodeURIComponent(nik)}`)
      .then(r => r.json())
      .then(d => {
        this.provTarget.textContent = d.province?.name || '—'
        this.regTarget.textContent = d.regency?.name || '—'
        this.disTarget.textContent = d.district?.name || '—'
        this.birthTarget.textContent = d.birthdate || '—'
        this.genderTarget.textContent = d.gender || '—'

        // Prefill dropdown domisili sesuai hasil parsing NIK
        this.prefillDomicile(d)
      })
  }

  async prefillDomicile(parsed) {
    // Set provinsi, lalu load kab/kota -> set, lalu load kecamatan -> set, lalu load kelurahan (tanpa set)
    const provCode = parsed.province?.code_norm
    const regCode = parsed.regency?.code_norm
    const disCode = parsed.district?.code_norm
    if (!provCode || !regCode || !disCode) return

    // Pilih provinsi
    if (this.hasDomProvTarget) {
      this.domProvTarget.value = provCode
      await this.loadRegencies({ target: this.domProvTarget }, { keepSelection: true })
    }

    // Pilih kab/kota
    if (this.hasDomRegTarget) {
      this.domRegTarget.value = regCode
      await this.loadDistricts({ target: this.domRegTarget }, { keepSelection: true })
    }

    // Pilih kecamatan
    if (this.hasDomDisTarget) {
      this.domDisTarget.value = disCode
      await this.loadVillages({ target: this.domDisTarget })
    }
  }

  async loadRegencies(e) {
    const prov = e.target.value
    if (!prov) {
      this.domRegTarget.innerHTML = '<option value="">-- Pilih Kab/Kota --</option>'
      this.domDisTarget.innerHTML = '<option value="">-- Pilih Kecamatan --</option>'
      if (this.hasDomVilTarget) this.domVilTarget.innerHTML = '<option value="">-- Pilih Kelurahan/Desa --</option>'
      return
    }
    const opts = await (await fetch(`/api/wilayah/children?parent=${prov}&level=2`)).json()
    this.domRegTarget.innerHTML = '<option value="">-- Pilih Kab/Kota --</option>' + opts.map(o => `<option value="${o.code}">${o.name}</option>`).join('')
    this.domDisTarget.innerHTML = '<option value="">-- Pilih Kecamatan --</option>'
    if (this.hasDomVilTarget) this.domVilTarget.innerHTML = '<option value="">-- Pilih Kelurahan/Desa --</option>'
  }
  
  async loadDistricts(e) {
    const reg = e.target.value
    if (!reg) {
      this.domDisTarget.innerHTML = '<option value="">-- Pilih Kecamatan --</option>'
      if (this.hasDomVilTarget) this.domVilTarget.innerHTML = '<option value="">-- Pilih Kelurahan/Desa --</option>'
      return
    }
    const opts = await (await fetch(`/api/wilayah/children?parent=${reg}&level=3`)).json()
    this.domDisTarget.innerHTML = '<option value="">-- Pilih Kecamatan --</option>' + opts.map(o => `<option value="${o.code}">${o.name}</option>`).join('')
    if (this.hasDomVilTarget) this.domVilTarget.innerHTML = '<option value="">-- Pilih Kelurahan/Desa --</option>'
  }

  async loadVillages(e) {
    const dis = e.target.value
    if (!this.hasDomVilTarget) return
    if (!dis) {
      this.domVilTarget.innerHTML = '<option value="">-- Pilih Kelurahan/Desa --</option>'
      return
    }
    const opts = await (await fetch(`/api/wilayah/children?parent=${dis}&level=4`)).json()
    this.domVilTarget.innerHTML = '<option value="">-- Pilih Kelurahan/Desa --</option>' + opts.map(o => `<option value="${o.code}">${o.name}</option>`).join('')
  }
}