import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static targets = ["nik", "prov", "reg", "dis", "birth", "gender", "domProv", "domReg", "domDis"]
  
  connect() { 
    this.onInput()
    // Pastikan domisili tersembunyi saat halaman dimuat
    const domWrap = document.getElementById('dom-wrap')
    const checkbox = document.getElementById('domicile-checkbox')
    if (domWrap && checkbox) {
      domWrap.classList.toggle('hidden', !checkbox.checked)
    }
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
      })
  }
  
  toggleDomicile(e) {
    const domWrap = document.getElementById('dom-wrap')
    if (domWrap) {
      domWrap.classList.toggle('hidden', !e.target.checked)
    }
  }
  
  async loadRegencies(e) {
    const prov = e.target.value
    if (!prov) {
      this.domRegTarget.innerHTML = '<option value="">-- Pilih Kab/Kota --</option>'
      this.domDisTarget.innerHTML = '<option value="">-- Pilih Kecamatan --</option>'
      return
    }
    const opts = await (await fetch(`/api/wilayah/children?parent=${prov}&level=2`)).json()
    this.domRegTarget.innerHTML = '<option value="">-- Pilih Kab/Kota --</option>' + opts.map(o => `<option value="${o.code}">${o.name}</option>`).join('')
    this.domDisTarget.innerHTML = '<option value="">-- Pilih Kecamatan --</option>'
  }
  
  async loadDistricts(e) {
    const reg = e.target.value
    if (!reg) {
      this.domDisTarget.innerHTML = '<option value="">-- Pilih Kecamatan --</option>'
      return
    }
    const opts = await (await fetch(`/api/wilayah/children?parent=${reg}&level=3`)).json()
    this.domDisTarget.innerHTML = '<option value="">-- Pilih Kecamatan --</option>' + opts.map(o => `<option value="${o.code}">${o.name}</option>`).join('')
  }
}