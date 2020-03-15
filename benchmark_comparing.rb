class BenchmarkComparing

  REPORT_SIZES = [100, 1000, 5000]

  def initialize

  end

  def run
    Benchmark.ips do |x|
      # The default is :stats => :sd, which doesn't have a configurable confidence
      # confidence is 95% by default, so it can be omitted
      x.config(:stats => :bootstrap, :confidence => 99)
      REPORT_SIZES.each do |rows_count|
        x.report("to_xlsx_export #{rows_count} rows") { 
          path = file_path('xlsx')
          to_xls_export(rows_count).serialize(path)
          puts path
        }
        x.report("to_csv_export #{rows_count} rows") {
          path = file_path('csv')
          to_csv_export(rows_count, path)
          puts path
        }
      end
      x.compare!
    end
  end


  def to_xls_export(rows_count)
    Axlsx::Package.new do |xlsx_package|
      workbook = xlsx_package.workbook
      worksheet = workbook.add_worksheet(name: 'Export')

      header_style = worksheet.styles.add_style(b: true, alignment: { horizontal: :center, vertical: :center })
      basic_style = worksheet.styles.add_style(b: false, alignment: { horizontal: :center, vertical: :center })

      worksheet.add_row(export_headers, style: header_style)

      rows_count.times do
        begin
          data = export_row

          types = Array.new(data.count, :string)

          worksheet.add_row(data, style: basic_style, types: types)
        rescue StandardError => e
          puts e.to_s
        end
      end
      puts 
    end
  end

  ##
  # Запись данных в csv файл.
  def to_csv_export(rows_count, path)
    CSV.open(path, 'w') do |csv|
      csv << export_headers

      rows_count.times do
        begin
          csv << export_row
        rescue StandardError => e
          puts e.to_s
        end
      end
    end
  end

  def file_path(format)
    Rails.public_path.join(Tempfile.new(['', ".#{format}"]).to_path)
  end

  def export_headers
    Array.new(20) { 'some header' }
  end

  def export_row
    Array.new(20) { 'some cell' }
  end
end
