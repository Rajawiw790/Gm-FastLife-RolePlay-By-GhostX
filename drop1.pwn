#define MAX_DROPPED_ITEMS       1000
#define DROP_EXPIRE_TIME        600     

#define DROP_LABEL_COLOR        0xFF0000FF  

enum droppedItems
{
    droppedID,
    droppedItem[32],
    droppedPlayer[24],
    droppedModel,
    droppedQuantity,
    Float:droppedPos[3],
    droppedWeapon,
    droppedAmmo,
    droppedInt,
    droppedWorld,
    droppedTime,
    STREAMER_TAG_OBJECT:droppedObject,
    STREAMER_TAG_3D_TEXT_LABEL:droppedText3D
};

new DroppedItems[MAX_DROPPED_ITEMS][droppedItems],
    Iterator:DROPPED<MAX_DROPPED_ITEMS>;

Dropped_Load()
{
    new rows;
    cache_get_row_count(rows);
    if(rows)
    {
        new id, i = 0;
        while(i < rows)
        {
            cache_get_value_name_int(i, "ID", id);

            if(id < 0 || id >= MAX_DROPPED_ITEMS) { i++; continue; }

            cache_get_value_name(i, "itemName", DroppedItems[id][droppedItem]);
            cache_get_value_name_int(i, "itemModel", DroppedItems[id][droppedModel]);
            cache_get_value_name_int(i, "itemQuantity", DroppedItems[id][droppedQuantity]);
            cache_get_value_name_float(i, "itemX", DroppedItems[id][droppedPos][0]);
            cache_get_value_name_float(i, "itemY", DroppedItems[id][droppedPos][1]);
            cache_get_value_name_float(i, "itemZ", DroppedItems[id][droppedPos][2]);
            cache_get_value_name_int(i, "itemInt", DroppedItems[id][droppedInt]);
            cache_get_value_name_int(i, "itemWorld", DroppedItems[id][droppedWorld]);
            cache_get_value_name_int(i, "itemTime", DroppedItems[id][droppedTime]);

            if(DroppedItems[id][droppedTime] > 0 && gettime() > DroppedItems[id][droppedTime])
            {
                new query[128];
                mysql_format(connectionID, query, sizeof(query), "DELETE FROM dropped WHERE ID='%d'", id);
                mysql_tquery(connectionID, query);
                i++;
                continue;
            }

            DroppedItems[id][droppedObject] = CreateDynamicObject(
                2663,
                DroppedItems[id][droppedPos][0],
                DroppedItems[id][droppedPos][1],
                DroppedItems[id][droppedPos][2],
                0.0, 0.0, 0.0,
                DroppedItems[id][droppedWorld],
                DroppedItems[id][droppedInt],
                -1,
                100.0,
                100.0
            );

            new label[128];
            format(label, sizeof(label), "%s [%dx]\n{YELLOW}[Y] To Pickup",
                DroppedItems[id][droppedItem],
                DroppedItems[id][droppedQuantity]);

            DroppedItems[id][droppedText3D] = CreateDynamic3DTextLabel(
                label,
                DROP_LABEL_COLOR,
                DroppedItems[id][droppedPos][0],
                DroppedItems[id][droppedPos][1],
                DroppedItems[id][droppedPos][2] + 0.8,
                30.0,
                INVALID_PLAYER_ID,
                INVALID_VEHICLE_ID,
                1,
                DroppedItems[id][droppedWorld],
                DroppedItems[id][droppedInt]
            );

            Iter_Add(DROPPED, id);
            i++;
        }
        printf("[DROPITEM] Loaded: %d Dropped Items", i);
    }
}

Dropped_Save(id)
{
    new cQuery[512];
    format(cQuery, sizeof(cQuery),
        "UPDATE dropped SET itemName='%s', itemModel='%d', itemQuantity='%d', itemX='%.4f', itemY='%.4f', itemZ='%.4f', itemInt='%d', itemWorld='%d', itemTime='%d' WHERE ID='%d'",
        DroppedItems[id][droppedItem],
        DroppedItems[id][droppedModel],
        DroppedItems[id][droppedQuantity],
        DroppedItems[id][droppedPos][0],
        DroppedItems[id][droppedPos][1],
        DroppedItems[id][droppedPos][2],
        DroppedItems[id][droppedInt],
        DroppedItems[id][droppedWorld],
        DroppedItems[id][droppedTime],
        id
    );
    return mysql_tquery(connectionID, cQuery);
}

forward DropItem(name[], itemid, value, Float:x, Float:y, Float:z, interior, world);
public DropItem(name[], itemid, value, Float:x, Float:y, Float:z, interior, world)
{
    new query[512];
    new id = Iter_Free(DROPPED);

    if(id == -1) return 0;

    format(DroppedItems[id][droppedItem], 32, name);
    DroppedItems[id][droppedModel] = itemid;
    DroppedItems[id][droppedPos][0] = x;
    DroppedItems[id][droppedPos][1] = y;
    DroppedItems[id][droppedPos][2] = z;
    DroppedItems[id][droppedQuantity] = value;
    DroppedItems[id][droppedInt] = interior;
    DroppedItems[id][droppedWorld] = world;
    DroppedItems[id][droppedTime] = gettime() + DROP_EXPIRE_TIME;

    // ? ?????
    DroppedItems[id][droppedObject] = CreateDynamicObject(
        2663,
        x, y, z,
        0.0, 0.0, 0.0,
        world, interior,
        -1,
        100.0,
        100.0
    );

    new label[128];
    format(label, sizeof(label), "%s [%dx]\n{YELLOW}[Y] To Pickup", name, value);

    DroppedItems[id][droppedText3D] = CreateDynamic3DTextLabel(
        label,
        DROP_LABEL_COLOR,
        x, y, z + 0.8,
        30.0,
        INVALID_PLAYER_ID,
        INVALID_VEHICLE_ID,
        1,
        world, interior
    );

    Iter_Add(DROPPED, id);

    mysql_format(connectionID, query, sizeof(query),
        "INSERT INTO dropped SET ID='%d', itemName='%s', itemModel='%d', itemQuantity='%d', itemX='%.4f', itemY='%.4f', itemZ='%.4f', itemInt='%d', itemWorld='%d', itemTime='%d'",
        id, name, itemid, value, x, y, z, interior, world, DroppedItems[id][droppedTime]);
    mysql_tquery(connectionID, query, "OnDroppedItem", "d", id);

    return 1;
}

forward OnDroppedItem(id);
public OnDroppedItem(id)
{
    Dropped_Save(id);
    return 1;
}

stock DropFail(playerid, const msg[])
{
    SCM(playerid, COLOR_SYNTAX, msg);
    return 0;
}

forward DropPlayerItem(playerid, itemid, name[], value);
public DropPlayerItem(playerid, itemid, name[], value)
{
    new Float:x, Float:y, Float:z;
    new str[32];

    if(value < 1) return DropFail(playerid, "Invalid amount.");
    if(value > 1000) return DropFail(playerid, "Max 1000.");

    GetPlayerPos(playerid, x, y, z);

    if(!strcmp(name, "Cash", true) || !strcmp(name, "Money", true))
    {
        if(pData[playerid][pCash] < value) return DropFail(playerid, "Not enough cash.");
        itemid = 18866;
        format(str, sizeof(str), "Removed_%dx", value);
        pData[playerid][pCash] -= value;
    }
    else if(!strcmp(name, "Phone", true))
    {
        if(pData[playerid][pPhone] < value) return DropFail(playerid, "Not enough phones.");
        itemid = 18866;
        pData[playerid][pPhone] -= value;
    }
    else if(!strcmp(name, "Radio", true))
    {
        if(pData[playerid][pWalkieTalkie] < value) return DropFail(playerid, "Not enough radios.");
        itemid = 330;
        pData[playerid][pWalkieTalkie] -= value;
    }
    else if(!strcmp(name, "Mask", true))
    {
        if(pData[playerid][pMask] < value) return DropFail(playerid, "Not enough masks.");
        itemid = 18914;
        pData[playerid][pMask] -= value;
    }
    else if(!strcmp(name, "Medkit", true))
    {
        if(pData[playerid][pMedkit] < value) return DropFail(playerid, "Not enough medkits.");
        itemid = 11748;
        pData[playerid][pMedkit] -= value;
    }
    else if(!strcmp(name, "Repair Kit", true))
    {
        if(pData[playerid][pRepairKit] < value) return DropFail(playerid, "Not enough repair kits.");
        itemid = 920;
        pData[playerid][pRepairKit] -= value;
    }
    else if(!strcmp(name, "Food", true))
    {
        if(pData[playerid][pFood] < value) return DropFail(playerid, "Not enough food.");
        itemid = 2703;
        pData[playerid][pFood] -= value;
    }
    else if(!strcmp(name, "Drink", true))
    {
        if(pData[playerid][pDrink] < value) return DropFail(playerid, "Not enough drinks.");
        itemid = 2647;
        pData[playerid][pDrink] -= value;
    }
    else if(!strcmp(name, "Bandage", true))
    {
        if(pData[playerid][pBandage] < value) return DropFail(playerid, "Not enough bandages.");
        itemid = 11747;
        pData[playerid][pBandage] -= value;
    }
    else if(!strcmp(name, "Lockpick", true))
    {
        if(pData[playerid][pLockpick] < value) return DropFail(playerid, "Not enough lockpicks.");
        itemid = 11747;
        pData[playerid][pLockpick] -= value;
    }
    else if(!strcmp(name, "Painkillers", true))
    {
        if(pData[playerid][pPainkillers] < value) return DropFail(playerid, "Not enough painkillers.");
        itemid = 11736;
        pData[playerid][pPainkillers] -= value;
    }
    else if(!strcmp(name, "Bitcoin", true))
    {
        if(pData[playerid][pBitcoin] < value) return DropFail(playerid, "Not enough bitcoins.");
        itemid = 19874;
        pData[playerid][pBitcoin] -= value;
    }
    else if(!strcmp(name, "Darkcoin", true))
    {
        if(pData[playerid][pDarkcoin] < value) return DropFail(playerid, "Not enough darkcoins.");
        itemid = 19874;
        pData[playerid][pDarkcoin] -= value;
    }
    else if(!strcmp(name, "Eth", true))
    {
        if(pData[playerid][pEth] < value) return DropFail(playerid, "Not enough eth.");
        itemid = 19874;
        pData[playerid][pEth] -= value;
    }
    else if(!strcmp(name, "Usb", true))
    {
        if(pData[playerid][pusb] < value) return DropFail(playerid, "Not enough usbs.");
        itemid = 1210;
        pData[playerid][pusb] -= value;
    }
    else if(!strcmp(name, "Pot", true))
    {
        if(pData[playerid][pPot] < value) return DropFail(playerid, "Not enough pot.");
        itemid = 19473;
        pData[playerid][pPot] -= value;
    }
    else if(!strcmp(name, "Crack", true))
    {
        if(pData[playerid][pCrack] < value) return DropFail(playerid, "Not enough crack.");
        itemid = 1575;
        pData[playerid][pCrack] -= value;
    }
    else if(!strcmp(name, "Meth", true))
    {
        if(pData[playerid][pMeth] < value) return DropFail(playerid, "Not enough meth.");
        itemid = 2866;
        pData[playerid][pMeth] -= value;
    }
    else if(!strcmp(name, "Seeds", true))
    {
        if(pData[playerid][pSeeds] < value) return DropFail(playerid, "Not enough seeds.");
        itemid = 2663;
        pData[playerid][pSeeds] -= value;
    }
    else if(!strcmp(name, "Boombox", true))
    {
        if(pData[playerid][pBoombox] < value) return DropFail(playerid, "Not enough boomboxes.");
        itemid = 2103;
        pData[playerid][pBoombox] -= value;
    }
    else return DropFail(playerid, "Invalid item name.");

    ApplyAnimation(playerid, "CARRY", "putdwn", 4.0, 0, 1, 1, 0, 0, 1);

    DropItem(name, itemid, value, x, y, z - 0.9, GetPlayerInterior(playerid), GetPlayerVirtualWorld(playerid));

    return 1;
}

NearItemDropped(playerid, targetid, Float:radius)
{
    return (IsPlayerInRangeOfPoint(playerid, radius,
        DroppedItems[targetid][droppedPos][0],
        DroppedItems[targetid][droppedPos][1],
        DroppedItems[targetid][droppedPos][2]));
}

forward TakePlayerItem(playerid, id, name[]);
public TakePlayerItem(playerid, id, name[])
{
    if(id < 0 || id >= MAX_DROPPED_ITEMS) return 0;
    if(!Iter_Contains(DROPPED, id)) return 0;

    new qty = DroppedItems[id][droppedQuantity];

    if(!strcmp(name, "Cash", true))              pData[playerid][pCash] += qty;
    else if(!strcmp(name, "Phone", true))        pData[playerid][pPhone] += qty;
    else if(!strcmp(name, "Radio", true))        pData[playerid][pWalkieTalkie] += qty;
    else if(!strcmp(name, "Mask", true))         pData[playerid][pMask] += qty;
    else if(!strcmp(name, "Medkit", true))       pData[playerid][pMedkit] += qty;
    else if(!strcmp(name, "Repair Kit", true))   pData[playerid][pRepairKit] += qty;
    else if(!strcmp(name, "Food", true))         pData[playerid][pFood] += qty;
    else if(!strcmp(name, "Drink", true))        pData[playerid][pDrink] += qty;
    else if(!strcmp(name, "Bandage", true))      pData[playerid][pBandage] += qty;
    else if(!strcmp(name, "Painkillers", true))  pData[playerid][pPainkillers] += qty;
    else if(!strcmp(name, "Lockpick", true))     pData[playerid][pLockpick] += qty;
    else if(!strcmp(name, "Bitcoin", true))      pData[playerid][pBitcoin] += qty;
    else if(!strcmp(name, "Darkcoin", true))     pData[playerid][pDarkcoin] += qty;
    else if(!strcmp(name, "Eth", true))          pData[playerid][pEth] += qty;
    else if(!strcmp(name, "Usb", true))          pData[playerid][pusb] += qty;
    else if(!strcmp(name, "Pot", true))          pData[playerid][pPot] += qty;
    else if(!strcmp(name, "Crack", true))        pData[playerid][pCrack] += qty;
    else if(!strcmp(name, "Meth", true))         pData[playerid][pMeth] += qty;
    else if(!strcmp(name, "Seeds", true))        pData[playerid][pSeeds] += qty;
    else if(!strcmp(name, "Boombox", true))      pData[playerid][pBoombox] += qty;

    DeleteDroppedItem(id);
    return 1;
}

stock DeleteDroppedItem(id)
{
    if(id < 0 || id >= MAX_DROPPED_ITEMS) return 0;

    if(DroppedItems[id][droppedObject] != STREAMER_TAG_OBJECT:INVALID_STREAMER_ID)
    {
        DestroyDynamicObject(DroppedItems[id][droppedObject]);
        DroppedItems[id][droppedObject] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
    }

    if(DroppedItems[id][droppedText3D] != STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID)
    {
        DestroyDynamic3DTextLabel(DroppedItems[id][droppedText3D]);
        DroppedItems[id][droppedText3D] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
    }

    DroppedItems[id][droppedModel] = 0;
    DroppedItems[id][droppedQuantity] = 0;
    DroppedItems[id][droppedItem][0] = EOS;
    DroppedItems[id][droppedTime] = 0;

    Iter_Remove(DROPPED, id);

    new query[128];
    mysql_format(connectionID, query, sizeof(query), "DELETE FROM dropped WHERE ID='%d'", id);
    mysql_tquery(connectionID, query);
    return 1;
}

forward DroppedItemsTimer();
public DroppedItemsTimer()
{
    new count = 0;
    foreach(new i : DROPPED)
    {
        if(DroppedItems[i][droppedTime] > 0 && gettime() > DroppedItems[i][droppedTime])
        {
            DeleteDroppedItem(i);
            count++;
        }
    }
    if(count > 0) printf("[DROPITEM] Auto-deleted %d expired items.", count);
    return 1;
}

stock GetNearestDroppedItem(playerid, Float:radius)
{
    new nearest = -1;
    new Float:nearest_dist = radius + 1.0;
    new Float:dist;

    foreach(new i : DROPPED)
    {
        if(DroppedItems[i][droppedInt] != GetPlayerInterior(playerid)) continue;
        if(DroppedItems[i][droppedWorld] != GetPlayerVirtualWorld(playerid)) continue;

        dist = GetPlayerDistanceFromPoint(playerid,
            DroppedItems[i][droppedPos][0],
            DroppedItems[i][droppedPos][1],
            DroppedItems[i][droppedPos][2]);

        if(dist < nearest_dist)
        {
            nearest_dist = dist;
            nearest = i;
        }
    }
    return nearest;
}


CMD:takedrop(playerid)
{
    new count = 0, str[500], strr[500];
    foreach(new i : DROPPED) if(NearItemDropped(playerid, i, 7))
    {
        format(str, sizeof(str), " %d\t %s[%d]\n", i, DroppedItems[i][droppedItem], DroppedItems[i][droppedQuantity]);
        strcat(strr, str);
        count++;
    }

    if(!count)
    {
        SCM(playerid, COLOR_SYNTAX, "No items nearby.");
        return 1;
    }

    ShowPlayerDialog(playerid, DIALOG_TAKE, DIALOG_STYLE_LIST, "Dropped Items", strr, "Take", "Close");
    return 1;
}
