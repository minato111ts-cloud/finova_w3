-- Grain: 1 dòng = 1 mã chứng khoán. Mã chỉ thấy ở lệnh (XYZ) vẫn vào hub
{{ dv_hub(hk='instrument_hk', bk='symbol',
          sources=['stg_luyen_tap__instruments', 'stg_luyen_tap__orders']) }}
