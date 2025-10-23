module ApplicationHelper
  # Format nomor KTA dengan titik separator dan prefix NAGR
  # Contoh: 320101000001 -> NAGR: 320101.000001
  def format_kta_number(kta_number)
    return nil unless kta_number
    if kta_number.length == 12
      "NAGR: #{kta_number[0..5]}.#{kta_number[6..11]}"
    else
      "NAGR: #{kta_number}"
    end
  end
end
