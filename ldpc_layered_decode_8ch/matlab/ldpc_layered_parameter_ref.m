function sched = ldpc_layered_parameter_ref(coePath, iv_len, iv_rate)
%LDPC_LAYERED_PARAMETER_REF  MATLAB reference for ldpc_layered_parameter.vhd.
%
% First target:
%   DVB-S2 short frame 3/4, named 11/15 in the existing project
%   iv_len  = "10"
%   iv_rate = "001101"
%
% The function decodes the same 156 schedule words used by the VHDL module:
%   12 layers * 13 slots/layer.
%
% Output fields correspond to VHDL outputs:
%   rom_addr, word_valid, row_start, row_end, row_active, edge_valid,
%   dummy, pos_en_raw, layer_idx, slot_idx, pos, msg_addr, fwd_shift,
%   rev_shift.

    if nargin < 1 || isempty(coePath)
        thisDir = fileparts(mfilename('fullpath'));
        coePath = fullfile(thisDir, '..', 'ldpc_decode_parameter_rom.coe');
    end
    if nargin < 2 || isempty(iv_len)
        iv_len = '10';
    end
    if nargin < 3 || isempty(iv_rate)
        iv_rate = '001101';
    end

    if ~(strcmp(iv_len, '10') && strcmp(iv_rate, '001101'))
        error('This first reference model only supports short-frame 11/15 / DVB-S2 3/4.');
    end

    ROM_BASE = 27859;
    LAYER_NUM = 12;
    SLOT_PER_LAYER = 13;
    SCHED_WORDS = LAYER_NUM * SLOT_PER_LAYER;
    DUMMY_POS = 181;

    romWords = read_coe_binary_words(coePath);
    msgAddr = 0;

    emptyRow = struct( ...
        'rom_addr', 0, ...
        'word_valid', false, ...
        'row_start', false, ...
        'row_end', false, ...
        'row_active', false, ...
        'edge_valid', false, ...
        'dummy', false, ...
        'pos_en_raw', false, ...
        'layer_idx', 0, ...
        'slot_idx', 0, ...
        'pos', 0, ...
        'msg_addr', 0, ...
        'fwd_shift', 0, ...
        'rev_shift', 0);

    sched = repmat(emptyRow, SCHED_WORDS, 1);

    for k = 1:SCHED_WORDS
        romAddr = ROM_BASE + k - 1;
        bits = romWords{romAddr + 1}; % ROM address is zero-based, MATLAB index is one-based.

        weight = bits(1) == '1';
        posEnRaw = bits(2) == '1';
        pos = bin2dec(bits(3:10));
        shift = bin2dec(bits(11:19));

        % weight=0 is the final slot marker of a CN row, not an invalid slot.
        % Every non-dummy slot owns one check-message RAM address.
        isDummy = (pos == DUMMY_POS);
        isEdge = (pos ~= DUMMY_POS);

        sched(k).rom_addr = romAddr;
        sched(k).word_valid = true;
        sched(k).row_start = mod(k-1, SLOT_PER_LAYER) == 0;
        sched(k).row_end = ~weight;
        sched(k).row_active = weight;
        sched(k).edge_valid = isEdge;
        sched(k).dummy = isDummy;
        sched(k).pos_en_raw = posEnRaw;
        sched(k).layer_idx = floor((k-1) / SLOT_PER_LAYER);
        sched(k).slot_idx = mod(k-1, SLOT_PER_LAYER);
        sched(k).pos = pos;
        sched(k).msg_addr = msgAddr;
        sched(k).fwd_shift = shift;
        sched(k).rev_shift = reverse_shift_code(shift);

        if isEdge
            msgAddr = msgAddr + 1;
        end
    end
end

function words = read_coe_binary_words(coePath)
    txt = fileread(coePath);
    lines = regexp(txt, '\r\n|\n|\r', 'split');
    words = {};
    for i = 1:numel(lines)
        s = strtrim(lines{i});
        s = regexprep(s, '[,;]$', '');
        if numel(s) == 19 && all(s == '0' | s == '1')
            words{end+1, 1} = s; %#ok<AGROW>
        end
    end
end

function revShift = reverse_shift_code(rawShift)
% Mirrors reverse_shift_code() in ldpc_layered_parameter.vhd and the
% reverse branch in the old ldpc_decode_parameter.vhd.
    rawBits = dec2bin(rawShift, 9) - '0';
    revBits = zeros(1, 9);

    % rawBits positions are MSB..LSB: bit8 bit7 ... bit0.
    raw_8_7 = rawBits(1:2);
    raw_6_4 = rawBits(3:5);
    raw_3_0 = rawBits(6:9);

    rev_6_4 = 1 - raw_6_4;
    if all(raw_6_4 == 0)
        rev_8_7 = raw_8_7;
        rev_3_0 = raw_3_0;
    else
        rev_8_7 = 1 - raw_8_7;
        rev_3_0 = 1 - raw_3_0;
    end

    revBits(1:2) = rev_8_7;
    revBits(3:5) = rev_6_4;
    revBits(6:9) = rev_3_0;
    revShift = bin2dec(char(revBits + '0'));
end
